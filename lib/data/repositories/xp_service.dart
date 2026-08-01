import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad/core/constants/xp_constants.dart';
import 'package:vcroad/data/models/lesson_progress.dart';

class XpService {
  XpService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final XpService instance = XpService._();

  factory XpService.withFirestore(FirebaseFirestore firestore) =>
      XpService._(firestore: firestore);

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>> awardLessonComplete({
    required String userId,
    required int pointsEarned,
    required int totalPoints,
    required int durationMinutes,
    required int secondsSpent,
    required String lessonId,
    bool isPerfectScore = false,
  }) async {
    try {
      int xpEarned = XpConstants.xpPerLessonComplete;
      if (isPerfectScore) {
        xpEarned += XpConstants.xpBonusPerfectScore;
      }

      final isQuickLearner = durationMinutes > 0 &&
          secondsSpent < durationMinutes * 60 * 0.5;

      final userRef = _firestore.collection('users').doc(userId);
      final now = Timestamp.fromDate(DateTime.now());

      bool leveledUp = false;
      int newLevel = 1;

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(userRef);
        final data = snapshot.data() ?? {};
        final stats = Map<String, dynamic>.from(
          data['learningStats'] as Map? ?? {},
        );

        final currentXp = (stats['xp'] as num?)?.toInt() ?? 0;
        final oldLevel = XpConstants.getLevel(currentXp);
        final newXp = currentXp + xpEarned;
        newLevel = XpConstants.getLevel(newXp);
        leveledUp = newLevel > oldLevel;

        final nowDate = DateTime.now();
        final today = DateTime(nowDate.year, nowDate.month, nowDate.day);
        final lastActivity = stats['lastActivityDate'] != null
            ? (stats['lastActivityDate'] as Timestamp).toDate()
            : null;
        final lastActiveDay = lastActivity != null
            ? DateTime(lastActivity.year, lastActivity.month, lastActivity.day)
            : null;

        int currentStreak = (stats['currentStreak'] as num?)?.toInt() ?? 0;
        if (lastActiveDay != null) {
          final diff = today.difference(lastActiveDay).inDays;
          if (diff == 1) {
            currentStreak++;
            xpEarned += XpConstants.xpPerStreakDay * currentStreak;
          } else if (diff > 1) {
            currentStreak = 1;
          }
        } else {
          currentStreak = 1;
        }

        int longestStreak = (stats['longestStreak'] as num?)?.toInt() ?? 0;
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        tx.update(userRef, {
          'learningStats.xp': FieldValue.increment(xpEarned),
          'learningStats.level': newLevel,
          'learningStats.currentStreak': currentStreak,
          'learningStats.longestStreak': longestStreak,
          'learningStats.lastActivityDate': now,
        });
      });

      return {
        'xpEarned': xpEarned,
        'isQuickLearner': isQuickLearner,
        'leveledUp': leveledUp,
        'newLevel': newLevel,
      };
    } catch (e) {
      debugPrint('XpService.awardLessonComplete error: $e');
      return {'xpEarned': 0, 'isQuickLearner': false, 'leveledUp': false, 'newLevel': 1};
    }
  }

  Future<void> awardReview(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set({
        'learningStats.xp': FieldValue.increment(XpConstants.xpPerReview),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('XpService.awardReview error: $e');
    }
  }

  Future<void> awardReportAfterLearning(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.set({
        'learningStats.xp': FieldValue.increment(
          XpConstants.xpFirstReportAfterLesson,
        ),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('XpService.awardReportAfterLearning error: $e');
    }
  }

  Future<UserLearningStats> getStats(String userId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return UserLearningStats();

      final data = doc.data()!;
      final statsData = data['learningStats'] as Map<String, dynamic>?;
      if (statsData == null) return UserLearningStats();

      return UserLearningStats.fromJson(statsData);
    } catch (e) {
      debugPrint('XpService.getStats error: $e');
      return UserLearningStats();
    }
  }
}
