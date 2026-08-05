import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/lesson_progress.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/data/repositories/xp_service.dart';
import 'package:vcroad/data/repositories/badge_service.dart';

class LessonProgressService {
  final FirebaseFirestore _firestore;
  final XpService _xpService;
  final BadgeService _badgeService;
  final String _collection = 'lesson_progress';

  LessonProgressService._({
    FirebaseFirestore? firestore,
    XpService? xpService,
    BadgeService? badgeService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _xpService = xpService ?? XpService.instance,
        _badgeService = badgeService ?? BadgeService.instance;

  static final LessonProgressService instance = LessonProgressService._();

  factory LessonProgressService.withFirestore(FirebaseFirestore firestore) =>
      LessonProgressService._(firestore: firestore);

  Future<void> initializeUserProgress(String userId) async {
    try {
      final lessonsSnapshot = await _firestore
          .collection('lessons')
          .where('isPublished', isEqualTo: true)
          .orderBy('lessonNumber')
          .get();

      final existingSnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final existingLessonIds = existingSnapshot.docs
          .map((d) => d.data()['lessonId'] as String?)
          .whereType<String>()
          .toSet();

      final lessons = lessonsSnapshot.docs
          .map((doc) => Lesson.fromJson(doc.data()))
          .toList();

      final batch = _firestore.batch();
      final now = DateTime.now();
      String? prevChapterId;

      for (int i = 0; i < lessons.length; i++) {
        final lesson = lessons[i];
        final progressId = '${userId}_${lesson.id}';

        if (existingLessonIds.contains(lesson.id)) continue;

        final isFirstInChapter =
            prevChapterId == null || prevChapterId != lesson.chapterId;
        final isLocked = !(i == 0 || isFirstInChapter);

        final progress = LessonProgress(
          id: progressId,
          userId: userId,
          lessonId: lesson.id,
          chapterId: lesson.chapterId,
          lessonNumber: lesson.lessonNumber,
          isLocked: isLocked,
          totalQuestions: 0,
          totalPoints: lesson.pointsAvailable,
          lastAccessedAt: now,
        );

        batch.set(
          _firestore.collection(_collection).doc(progressId),
          progress.toJson(),
        );

        prevChapterId = lesson.chapterId;
      }

      await batch.commit();
    } catch (e) {
      debugPrint('LessonProgressService.initializeUserProgress error: $e');
      rethrow;
    }
  }

  Future<void> startLesson(String userId, String lessonId) async {
    try {
      final progressId = '${userId}_$lessonId';
      final now = Timestamp.now();

      await _firestore.collection(_collection).doc(progressId).set({
        'userId': userId,
        'startedAt': now,
        'lastAccessedAt': now,
        'attemptCount': FieldValue.increment(1),
        'questionsAnswered': 0,
        'questionsCorrect': 0,
        'pointsEarned': 0,
        'score': 0.0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('LessonProgressService.startLesson error: $e');
      rethrow;
    }
  }

  Future<void> submitAnswer({
    required String userId,
    required String lessonId,
    required QuizQuestion question,
    required dynamic userAnswer,
    required bool isCorrect,
  }) async {
    try {
      final progressId = '${userId}_$lessonId';
      final docRef = _firestore.collection(_collection).doc(progressId);

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) return;

        final progress = LessonProgress.fromJson(snapshot.data()!);
        final pointsEarned = isCorrect ? question.points : 0;

        final now = DateTime.now();
        final interval = _nextInterval(progress, question.id, isCorrect);
        final nextReviewAt = now.add(Duration(hours: interval));

        final attempt = QuestionAttempt(
          questionId: question.id,
          userAnswer: userAnswer?.toString(),
          isCorrect: isCorrect,
          pointsEarned: pointsEarned,
          attemptedAt: now,
          nextReviewAt: nextReviewAt,
          interval: interval,
        );

        final updatedAttempts = [...progress.attempts, attempt];
        final runStart =
            progress.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final runAttempts = updatedAttempts
            .where((a) => !a.attemptedAt.isBefore(runStart))
            .toList();

        final Map<String, int> bestPoints = {};
        final Map<String, bool> correctByQuestion = {};
        for (final a in runAttempts) {
          final prev = bestPoints[a.questionId] ?? 0;
          if (a.pointsEarned > prev) {
            bestPoints[a.questionId] = a.pointsEarned;
          }
          correctByQuestion[a.questionId] =
              (correctByQuestion[a.questionId] ?? false) || a.isCorrect;
        }

        final questionsAnswered = bestPoints.length;
        final questionsCorrect =
            correctByQuestion.values.where((v) => v).length;
        final totalPointsEarned =
            bestPoints.values.fold<int>(0, (acc, v) => acc + v);
        final score = progress.totalPoints > 0
            ? (totalPointsEarned / progress.totalPoints) * 100
            : 0.0;

        final overallNextReviewAt = isCorrect ? nextReviewAt : null;

        tx.update(docRef, {
          'attempts': updatedAttempts.map((a) => a.toJson()).toList(),
          'questionsAnswered': questionsAnswered,
          'questionsCorrect': questionsCorrect,
          'pointsEarned': totalPointsEarned,
          'score': score,
          'lastAccessedAt': Timestamp.now(),
          if (overallNextReviewAt != null)
            'nextReviewAt': Timestamp.fromDate(overallNextReviewAt),
        });
      });

      await _firestore.collection(_questionsCollection).doc(question.id).update({
        'timesAnswered': FieldValue.increment(1),
        if (isCorrect) 'timesCorrect': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('LessonProgressService.submitAnswer error: $e');
      rethrow;
    }
  }

  int _nextInterval(
    LessonProgress progress,
    String questionId,
    bool isCorrect,
  ) {
    if (!isCorrect) return 1;
    final prevAttempt = progress.attempts
        .where((a) => a.questionId == questionId)
        .toList();
    if (prevAttempt.isNotEmpty && prevAttempt.last.isCorrect) {
      return (prevAttempt.last.interval * 2).clamp(1, 168);
    }
    return 1;
  }

  Future<List<QuizQuestion>> getDueReviewQuestions(
    String userId,
    String lessonId, {
    bool onlyDue = true,
  }) async {
    try {
      final progressId = '${userId}_$lessonId';
      final progressDoc = await _firestore
          .collection(_collection)
          .doc(progressId)
          .get();
      if (!progressDoc.exists) return [];

      final progress = LessonProgress.fromJson(progressDoc.data()!);
      if (progress.attempts.isEmpty) return [];

      final now = DateTime.now();
      final Set<String>? dueQuestionIds;
      if (onlyDue) {
        dueQuestionIds = progress.attempts
            .where((a) => a.nextReviewAt != null && a.nextReviewAt!.isBefore(now))
            .map((a) => a.questionId)
            .toSet();
        if (dueQuestionIds.isEmpty) return [];
      } else {
        dueQuestionIds = null;
      }

      final questionsSnapshot = await _firestore
          .collection(_questionsCollection)
          .where('lessonId', isEqualTo: lessonId)
          .orderBy('order')
          .get();

      if (!onlyDue) {
        final attemptedIds = progress.attempts.map((a) => a.questionId).toSet();
        return questionsSnapshot.docs
            .map((doc) => QuizQuestion.fromJson(doc.data()))
            .where((q) => attemptedIds.contains(q.id))
            .toList();
      }

      return questionsSnapshot.docs
          .map((doc) => QuizQuestion.fromJson(doc.data()))
          .where((q) => dueQuestionIds!.contains(q.id))
          .toList();
    } catch (e) {
      debugPrint('LessonProgressService.getDueReviewQuestions error: $e');
      return [];
    }
  }

  Future<void> submitReviewAnswer({
    required String userId,
    required String lessonId,
    required QuizQuestion question,
    required dynamic userAnswer,
    required bool isCorrect,
  }) async {
    try {
      final progressId = '${userId}_$lessonId';
      final docRef = _firestore.collection(_collection).doc(progressId);

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) return;

        final progress = LessonProgress.fromJson(snapshot.data()!);
        final now = DateTime.now();
        final interval = _nextInterval(progress, question.id, isCorrect);
        final nextReviewAt = now.add(Duration(hours: interval));

        final attempt = QuestionAttempt(
          questionId: question.id,
          userAnswer: userAnswer?.toString(),
          isCorrect: isCorrect,
          pointsEarned: isCorrect ? question.points : 0,
          attemptedAt: now,
          nextReviewAt: nextReviewAt,
          interval: interval,
        );

        final updatedAttempts = [...progress.attempts, attempt];
        tx.update(docRef, {
          'attempts': updatedAttempts.map((a) => a.toJson()).toList(),
          'lastAccessedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      debugPrint('LessonProgressService.submitReviewAnswer error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeReview(
    String userId,
    String lessonId,
  ) async {
    try {
      final progressId = '${userId}_$lessonId';
      final docRef = _firestore.collection(_collection).doc(progressId);

      final doc = await docRef.get();
      if (!doc.exists) {
        return {'xpEarned': 0, 'reviewCount': 0, 'earnedBadges': <String>[]};
      }

      final progress = LessonProgress.fromJson(doc.data()!);
      if (progress.attempts.isEmpty) {
        return {
          'xpEarned': 0,
          'reviewCount': progress.reviewCount,
          'earnedBadges': <String>[],
        };
      }

      final now = DateTime.now();
      final futureTimes = progress.attempts
          .map((a) => a.nextReviewAt)
          .whereType<DateTime>()
          .where((t) => t.isAfter(now))
          .toList();
      final DateTime? nextReviewAt = futureTimes.isEmpty
          ? null
          : futureTimes.reduce((a, b) => a.isBefore(b) ? a : b);

      await docRef.update({
        'reviewCount': FieldValue.increment(1),
        if (nextReviewAt != null)
          'nextReviewAt': Timestamp.fromDate(nextReviewAt)
        else
          'nextReviewAt': FieldValue.delete(),
        'lastAccessedAt': Timestamp.now(),
      });

      final xpEarned = await _xpService.awardReview(userId);

      final updatedDoc = await docRef.get();
      final updatedProgress = LessonProgress.fromJson(updatedDoc.data()!);

      final earnedBadges = await _badgeService.checkAndAward(
        userId: userId,
        lessonId: lessonId,
        progress: updatedProgress,
        durationMinutes: 0,
        secondsSpent: 0,
        questionCount: updatedProgress.questionsAnswered,
      );

      return {
        'xpEarned': xpEarned,
        'reviewCount': updatedProgress.reviewCount,
        'earnedBadges': earnedBadges,
        'nextReviewAt': nextReviewAt,
      };
    } catch (e) {
      debugPrint('LessonProgressService.completeReview error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeLesson(String userId, String lessonId) async {
    try {
      final progressId = '${userId}_$lessonId';
      final docRef = _firestore.collection(_collection).doc(progressId);

      final result = await _firestore.runTransaction<Map<String, dynamic>?>((
        tx,
      ) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) return null;

        final data = snapshot.data()!;
        final prevCompleted = data['isCompleted'] as bool? ?? false;

        if (!prevCompleted) {
          double score = (data['score'] as num?)?.toDouble() ?? -1.0;
          if (score < 0) {
            final totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
            final pointsEarned = (data['pointsEarned'] as num?)?.toInt() ?? 0;
            score = totalPoints > 0
                ? (pointsEarned / totalPoints) * 100.0
                : 0.0;
          }

          const double passThreshold = 70.0;
          final bool passed = score >= passThreshold;

          final now = Timestamp.fromDate(DateTime.now());

          if (passed) {
            tx.update(docRef, {
              'isCompleted': true,
              'completedAt': now,
              'lastAccessedAt': now,
              'score': score,
            });

            final userRef = _firestore.collection('users').doc(userId);
            tx.set(userRef, {
              'learningStats.completedLessons': FieldValue.increment(1),
              'learningStats.totalPointsEarned': FieldValue.increment(
                (data['pointsEarned'] as num?)?.toInt() ?? 0,
              ),
              'learningStats.totalPointsAvailable': FieldValue.increment(
                (data['totalPoints'] as num?)?.toInt() ?? 0,
              ),
              'learningStats.lastActivityDate': now,
              'lastActivityAt': now,
            }, SetOptions(merge: true));
          }

          return {'passed': passed, 'score': score};
        }

        return const <String, dynamic>{'alreadyCompleted': true};
      });

      if (result == null) return {};
      if (result['alreadyCompleted'] == true) return result.cast<String, dynamic>();

      final updatedDoc = await docRef.get();
      if (!updatedDoc.exists) return result.cast<String, dynamic>();

      final updatedProgress = LessonProgress.fromJson(updatedDoc.data()!);
      if (updatedProgress.isPassed) {
        await _unlockNextLesson(userId, updatedProgress);

        final lessonDoc =
            await _firestore.collection('lessons').doc(lessonId).get();
        final lesson =
            lessonDoc.exists ? Lesson.fromJson(lessonDoc.data()!) : null;

        final now = DateTime.now();
        final secondsSpent = updatedProgress.startedAt != null
            ? now.difference(updatedProgress.startedAt!).inSeconds
            : 0;
        final durationMinutes = lesson?.durationMinutes ?? 0;
        final questionCount = updatedProgress.questionsAnswered;

        final xpResult = await _xpService.awardLessonComplete(
          userId: userId,
          pointsEarned: updatedProgress.pointsEarned,
          totalPoints: updatedProgress.totalPoints,
          durationMinutes: durationMinutes,
          secondsSpent: secondsSpent,
          lessonId: lessonId,
          isPerfectScore: updatedProgress.score >= 100,
        );

        final earnedBadges = await _badgeService.checkAndAward(
          userId: userId,
          lessonId: lessonId,
          progress: updatedProgress,
          durationMinutes: durationMinutes,
          secondsSpent: secondsSpent,
          questionCount: questionCount,
        );

        return {
          'passed': true,
          'score': result['score'],
          'xpEarned': xpResult['xpEarned'],
          'isQuickLearner': xpResult['isQuickLearner'],
          'leveledUp': xpResult['leveledUp'],
          'newLevel': xpResult['newLevel'],
          'earnedBadges': earnedBadges,
          'pointsEarned': updatedProgress.pointsEarned,
          'totalPoints': updatedProgress.totalPoints,
          'questionsCorrect': updatedProgress.questionsCorrect,
          'questionsAnswered': updatedProgress.questionsAnswered,
        };
      }

      return result.cast<String, dynamic>();
    } catch (e) {
      debugPrint('LessonProgressService.completeLesson error: $e');
      rethrow;
    }
  }

  Future<void> _unlockNextLesson(
    String userId,
    LessonProgress currentProgress,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isLocked', isEqualTo: true)
          .orderBy('lessonNumber')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return;

      final candidate = LessonProgress.fromJson(snapshot.docs.first.data());
      await _firestore.collection(_collection).doc(candidate.id).update({
        'isLocked': false,
      });
    } catch (e) {
      debugPrint('LessonProgressService._unlockNextLesson error: $e');
    }
  }

  Future<List<LessonProgress>> getUserProgress(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('lessonNumber')
          .get();

      return snapshot.docs
          .map((doc) => LessonProgress.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('LessonProgressService.getUserProgress error: $e');
      return [];
    }
  }

  Stream<List<LessonProgress>> watchUserProgress(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('lessonNumber')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LessonProgress.fromJson(doc.data()))
          .toList();
    });
  }

  Future<LessonProgress?> getLessonProgress(
    String userId,
    String lessonId,
  ) async {
    try {
      final progressId = '${userId}_$lessonId';
      final doc = await _firestore
          .collection(_collection)
          .doc(progressId)
          .get();

      if (!doc.exists) return null;
      return LessonProgress.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('LessonProgressService.getLessonProgress error: $e');
      return null;
    }
  }

  Future<UserLearningStats> getUserStats(String userId) async {
    try {
      final userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return UserLearningStats();

      final data = userDoc.data()!;
      final statsData = data['learningStats'] as Map<String, dynamic>?;

      if (statsData != null) {
        return UserLearningStats.fromJson(statsData);
      }

      return UserLearningStats();
    } catch (e) {
      debugPrint('LessonProgressService.getUserStats error: $e');
      return UserLearningStats();
    }
  }

  Future<Stream<UserLearningStats>> watchUserStats(String userId) async {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return UserLearningStats();
      final data = snapshot.data()!;
      final statsData = data['learningStats'] as Map<String, dynamic>?;
      if (statsData != null) return UserLearningStats.fromJson(statsData);
      return UserLearningStats();
    });
  }

  Future<void> resetLessonProgress(String userId, String lessonId) async {
    try {
      final progressId = '${userId}_$lessonId';
      await _firestore.collection(_collection).doc(progressId).update({
        'isCompleted': false,
        'questionsAnswered': 0,
        'questionsCorrect': 0,
        'pointsEarned': 0,
        'score': 0.0,
        'attempts': [],
        'startedAt': null,
        'completedAt': null,
        'attemptCount': 0,
        'nextReviewAt': null,
      });
    } catch (e) {
      debugPrint('LessonProgressService.resetLessonProgress error: $e');
      rethrow;
    }
  }

  String get _questionsCollection => 'questions';
}
