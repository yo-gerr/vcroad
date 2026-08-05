import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad/data/models/lesson_progress.dart';

class BadgeService {
  BadgeService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final BadgeService instance = BadgeService._();

  factory BadgeService.withFirestore(FirebaseFirestore firestore) =>
      BadgeService._(firestore: firestore);

  final FirebaseFirestore _firestore;

  Future<List<String>> checkAndAward({
    required String userId,
    required String lessonId,
    required LessonProgress progress,
    required int durationMinutes,
    required int secondsSpent,
    required int questionCount,
  }) async {
    try {
      final progressId = '${userId}_$lessonId';
      final progressRef =
          _firestore.collection('lesson_progress').doc(progressId);

      final earned = <String>[];

      final existingBadges = Set<String>.from(progress.badges);

      if (!existingBadges.contains('first_lesson')) {
        final count = await _countCompleted(userId);
        if (count <= 1) {
          earned.add('first_lesson');
        }
      }

      if (!existingBadges.contains('perfect_score') && progress.score >= 100) {
        earned.add('perfect_score');
      }

      if (!existingBadges.contains('quick_learner') &&
          durationMinutes > 0 &&
          secondsSpent < durationMinutes * 60 * 0.5) {
        earned.add('quick_learner');
      }

      if (!existingBadges.contains('streak_3') ||
          !existingBadges.contains('streak_7')) {
        final streak = await _getCurrentStreak(userId);
        if (streak >= 7 && !existingBadges.contains('streak_7')) {
          earned.add('streak_7');
        }
        if (streak >= 3 && !existingBadges.contains('streak_3')) {
          earned.add('streak_3');
        }
      }

      if (!existingBadges.contains('all_chapters')) {
        final allDone = await _checkAllChaptersCompleted(userId);
        if (allDone) {
          earned.add('all_chapters');
        }
      }

      if (!existingBadges.contains('review_master')) {
        final reviewsDone = await _countReviews(userId);
        if (reviewsDone >= 5) {
          earned.add('review_master');
        }
      }

      if (earned.isNotEmpty) {
        final updatedBadges = [...existingBadges, ...earned];
        await progressRef.update({'badges': updatedBadges});

        final userRef = _firestore.collection('users').doc(userId);
        for (final badge in earned) {
          userRef.set({
            'badges': FieldValue.arrayUnion([badge]),
          }, SetOptions(merge: true));
        }
      }

      return earned;
    } catch (e) {
      debugPrint('BadgeService.checkAndAward error: $e');
      return [];
    }
  }

  Future<int> _countCompleted(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('lesson_progress')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (_) {
      final snapshot = await _firestore
          .collection('lesson_progress')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    }
  }

  Future<int> _getCurrentStreak(String userId) async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;
      final stats = userDoc.data()!['learningStats'] as Map?;
      if (stats == null) return 0;
      return (stats['currentStreak'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> _checkAllChaptersCompleted(String userId) async {
    try {
      final chaptersSnap = await _firestore
          .collection('chapters')
          .get();
      if (chaptersSnap.docs.isEmpty) return false;

      final progressSnap = await _firestore
          .collection('lesson_progress')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .get();

      final completedChapterIds = progressSnap.docs
          .map((d) => d.data()['chapterId'] as String?)
          .whereType<String>()
          .toSet();

      for (final chapter in chaptersSnap.docs) {
        if (!completedChapterIds.contains(chapter.id)) {
          return false;
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> _countReviews(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('lesson_progress')
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        count += (doc.data()['reviewCount'] as num?)?.toInt() ?? 0;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }
}
