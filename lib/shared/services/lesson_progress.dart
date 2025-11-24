import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad_v2/shared/models/lesson.dart';
import 'package:vcroad_v2/shared/models/lesson_progress.dart';
import 'package:vcroad_v2/shared/models/question.dart';

class LessonProgressService {
  // Allow injection of a Firestore instance for tests while keeping a singleton for production
  LessonProgressService._internal([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final LessonProgressService instance =
      LessonProgressService._internal();

  // Factory for tests to inject a mock Firestore
  factory LessonProgressService.withFirestore(FirebaseFirestore firestore) =>
      LessonProgressService._internal(firestore);

  final FirebaseFirestore _firestore;
  final String _collection = 'lesson_progress';

  // Initialize progress for a user when they first access lessons
  Future<void> initializeUserProgress(String userId) async {
    try {
      final lessonsSnapshot = await _firestore
          .collection('lessons')
          .where('isPublished', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      final now = DateTime.now();

      // Sort lessons by chapter order and lesson number
      final lessons = lessonsSnapshot.docs
          .map((doc) => QuizMaterial.fromJson(doc.data()))
          .toList();

      lessons.sort((a, b) {
        final orderCompare = a.chapterOrder.compareTo(b.chapterOrder);
        if (orderCompare != 0) return orderCompare;
        return (a.lessonNumber ?? 0).compareTo(b.lessonNumber ?? 0);
      });

      // Prefetch existing progress docs for this user to avoid per-lesson reads
      final existingProgressSnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final existingLessonIds = existingProgressSnapshot.docs
          .map((d) => d.data()['lessonId'] as String?)
          .whereType<String>()
          .toSet();

      for (int i = 0; i < lessons.length; i++) {
        final lesson = lessons[i];
        final progressId = '${userId}_${lesson.id}';

        if (existingLessonIds.contains(lesson.id)) {
          continue; // progress already exists
        }

        final totalPoints = lesson.questions.fold<int>(
          0,
          (acc, q) => acc + q.points,
        );

        final progress = LessonProgress(
          id: progressId,
          userId: userId,
          lessonId: lesson.id,
          chapterCategory: lesson.chapterCategory,
          chapterOrder: lesson.chapterOrder,
          lessonNumber: lesson.lessonNumber,
          isLocked: i != 0, // First lesson is unlocked
          totalQuestions: lesson.questionCount,
          totalPoints: totalPoints,
          lastAccessedAt: now,
        );

        batch.set(
          _firestore.collection(_collection).doc(progressId),
          progress.toJson(),
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('LessonProgressService.initializeUserProgress error: $e');
      rethrow;
    }
  }

  // Start a lesson run: set startedAt, bump attemptCount, reset run-specific counters (server-side).
  Future<void> startLesson(String userId, String lessonId) async {
    try {
      final progressId = '${userId}_$lessonId';
      final docRef = _firestore.collection(_collection).doc(progressId);
      final now = Timestamp.now();

      // Merge update: preserve historic attempts array and other metadata, but reset run-specific counters.
      await docRef.set({
        'startedAt': now,
        'lastAccessedAt': now,
        'attemptCount': FieldValue.increment(1),
        // Reset run-specific counters so subsequent submitAnswer computes per-run totals
        'questionsAnswered': 0,
        'questionsCorrect': 0,
        'pointsEarned': 0,
        'scorePercentage': 0.0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('LessonProgressService.startLesson error: $e');
      rethrow;
    }
  }

  // Submit an answer
  Future<void> submitAnswer({
    required String userId,
    required String lessonId,
    required QuizQuestion question,
    required dynamic userAnswer,
    required bool isCorrect,
  }) async {
    try {
      final progressId = '${userId}_$lessonId';
      final doc = await _firestore
          .collection(_collection)
          .doc(progressId)
          .get();

      if (!doc.exists) {
        return;
      }

      final progress = LessonProgress.fromJson(doc.data()!);
      final pointsEarned = isCorrect ? question.points : 0;

      final attempt = QuestionAttempt(
        questionId: question.id,
        userAnswer: userAnswer?.toString(),
        isCorrect: isCorrect,
        pointsEarned: pointsEarned,
        attemptedAt: DateTime.now(),
      );

      // Keep history (append)
      final updatedAttempts = [...progress.attempts, attempt];

      // Determine the start time for the current run/attempt.
      // If startedAt is null, treat everything as current run to preserve behavior.
      final runStart =
          progress.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      // Filter attempts that belong to current run
      final runAttempts = updatedAttempts
          .where((a) => !a.attemptedAt.isBefore(runStart))
          .toList();

      // Compute per-question best points within the run (avoid double-counting repeated answers)
      final Map<String, int> bestPointsByQuestion = {};
      final Map<String, bool> correctByQuestion = {};
      for (final a in runAttempts) {
        final prev = bestPointsByQuestion[a.questionId] ?? 0;
        if (a.pointsEarned > prev) {
          bestPointsByQuestion[a.questionId] = a.pointsEarned;
        } // record if any attempt for the question was correct (useful for questionsCorrect)
        correctByQuestion[a.questionId] =
            (correctByQuestion[a.questionId] ?? false) || a.isCorrect;
      }

      final questionsAnswered = bestPointsByQuestion.length;
      final questionsCorrect = correctByQuestion.values.where((v) => v).length;
      final totalPointsEarned = bestPointsByQuestion.values.fold<int>(
        0,
        (acc, v) => acc + v,
      );

      final scorePercentage = progress.totalPoints > 0
          ? (totalPointsEarned / progress.totalPoints) * 100
          : 0.0;

      await _firestore.collection(_collection).doc(progressId).update({
        'attempts': updatedAttempts.map((a) => a.toJson()).toList(),
        'questionsAnswered': questionsAnswered,
        'questionsCorrect': questionsCorrect,
        'pointsEarned': totalPointsEarned,
        'scorePercentage': scorePercentage,
        'lastAccessedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('LessonProgressService.submitAnswer error: $e');
      rethrow;
    }
  }

  // Complete a lesson
  Future<void> completeLesson(String userId, String lessonId) async {
    try {
      final progressId = '${userId}_$lessonId';
      final docRef = _firestore.collection(_collection).doc(progressId);

      final now = DateTime.now();

      // Use transaction to atomically mark completed only if passing criteria are met.
      final bool wasAlreadyCompleted = await _firestore.runTransaction<bool>((
        tx,
      ) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) {
          // nothing to do; indicate it was not previously completed
          return false;
        }

        final data = snapshot.data()!;
        final prevCompleted = data['isCompleted'] as bool? ?? false;

        if (!prevCompleted) {
          // Determine if user passed the lesson run.
          double score = (data['scorePercentage'] as num?)?.toDouble() ?? -1.0;
          if (score < 0) {
            final totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
            final pointsEarned = (data['pointsEarned'] as num?)?.toInt() ?? 0;
            score = totalPoints > 0
                ? (pointsEarned / totalPoints) * 100.0
                : 0.0;
          }

          const double passThreshold = 70.0;
          final bool passed = score >= passThreshold;

          if (passed) {
            // mark lesson completed and increment user's finished count atomically
            tx.update(docRef, {
              'isCompleted': true,
              'completedAt': Timestamp.fromDate(now),
              'lastAccessedAt': Timestamp.fromDate(now),
            });

            final userRef = _firestore.collection('users').doc(userId);
            // use set with merge to allow missing user doc (safer than update)
            tx.set(userRef, {
              'lessonsFinishedCount': FieldValue.increment(1),
              'lastActivityAt': Timestamp.fromDate(now),
            }, SetOptions(merge: true));
          } else {
            // Do not mark completed when not passed; update lastAccessedAt for recency.
            tx.update(docRef, {'lastAccessedAt': Timestamp.fromDate(now)});
          }

          return false; // we processed (was not previously completed)
        }

        // already completed previously
        return true;
      });

      // Re-read updated progress to decide unlocking and further logic
      final updatedDoc = await docRef.get();
      if (!updatedDoc.exists) return;

      final updatedProgress = LessonProgress.fromJson(updatedDoc.data()!);

      // Only run unlock logic if the lesson was NOT already completed before this operation
      // and the saved progress meets the passing criteria.
      if (!wasAlreadyCompleted && updatedProgress.isPassed) {
        await _unlockNextLesson(userId, updatedProgress);
      }
    } catch (e) {
      debugPrint('LessonProgressService.completeLesson error: $e');
      rethrow;
    }
  }

  // Unlock next lesson in sequence
  Future<void> _unlockNextLesson(
    String userId,
    LessonProgress currentProgress,
  ) async {
    try {
      // Query only locked lessons for this user ordered by chapter/lesson.
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isLocked', isEqualTo: true)
          .orderBy('chapterOrder')
          .orderBy('lessonNumber')
          .limit(50) // reasonable limit – adjust if you have very large content
          .get();

      // Find the first locked lesson that comes after the current one
      for (final doc in snapshot.docs) {
        final candidate = LessonProgress.fromJson(doc.data());
        final afterCurrent =
            (candidate.chapterOrder > currentProgress.chapterOrder) ||
            (candidate.chapterOrder == currentProgress.chapterOrder &&
                (candidate.lessonNumber ?? 0) >
                    (currentProgress.lessonNumber ?? 0));
        if (afterCurrent) {
          await _firestore.collection(_collection).doc(candidate.id).update({
            'isLocked': false,
          });
          break;
        }
      }
    } catch (e) {
      debugPrint('LessonProgressService._unlockNextLesson error: $e');
    }
  }

  // Get all progress for a user
  Future<List<LessonProgress>> getUserProgress(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('chapterOrder')
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

  // Get progress for a specific lesson
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

      if (!doc.exists) {
        return null;
      }
      return LessonProgress.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('LessonProgressService.getLessonProgress error: $e');
      return null;
    }
  }

  // Get user learning stats
  Future<UserLearningStats> getUserStats(String userId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      final dateSet = <DateTime>{};
      int totalLessons = 0;
      int lessonsCompleted = 0;
      int lessonsInProgress = 0;
      int totalPointsEarned = 0;
      int totalPointsAvailable = 0;
      double progressSum = 0.0;

      for (final doc in snap.docs) {
        final data = doc.data();
        totalLessons++;
        final last = (data['lastAccessedAt'] as Timestamp?)?.toDate();
        if (last != null) {
          dateSet.add(DateTime(last.year, last.month, last.day));
        }
        if ((data['isCompleted'] as bool?) == true) lessonsCompleted++;
        if ((data['isLocked'] as bool?) != true &&
            (data['isCompleted'] as bool?) != true) {
          lessonsInProgress++;
        }
        totalPointsEarned += (data['pointsEarned'] as num?)?.toInt() ?? 0;
        totalPointsAvailable += (data['totalPoints'] as num?)?.toInt() ?? 0;
        progressSum += (data['scorePercentage'] as num?)?.toDouble() ?? 0.0;
      }

      final overallProgress = totalLessons > 0
          ? progressSum / totalLessons
          : 0.0;

      int computeStreak(Set<DateTime> days, DateTime today) {
        var streak = 0;
        var d = DateTime(today.year, today.month, today.day);
        while (days.contains(d)) {
          streak++;
          d = d.subtract(const Duration(days: 1));
        }
        return streak;
      }

      final streak = computeStreak(dateSet, DateTime.now());
      final lastActivity = dateSet.isNotEmpty
          ? dateSet.reduce((a, b) => a.isAfter(b) ? a : b)
          : null;

      return UserLearningStats(
        totalLessonsAvailable: totalLessons,
        lessonsCompleted: lessonsCompleted,
        lessonsInProgress: lessonsInProgress,
        totalPointsEarned: totalPointsEarned,
        totalPointsAvailable: totalPointsAvailable,
        overallProgress: overallProgress,
        currentStreak: streak,
        lastActivityDate: lastActivity,
      );
    } catch (e) {
      debugPrint('LessonProgressService.getUserStats error: $e');
      return UserLearningStats(
        totalLessonsAvailable: 0,
        lessonsCompleted: 0,
        lessonsInProgress: 0,
        totalPointsEarned: 0,
        totalPointsAvailable: 0,
        overallProgress: 0.0,
      );
    }
  }

  // Reset progress for a lesson (admin feature)
  Future<void> resetLessonProgress(String userId, String lessonId) async {
    try {
      final progressId = '${userId}_$lessonId';
      await _firestore.collection(_collection).doc(progressId).update({
        'isCompleted': false,
        'questionsAnswered': 0,
        'questionsCorrect': 0,
        'pointsEarned': 0,
        'scorePercentage': 0.0,
        'attempts': [],
        'startedAt': null,
        'completedAt': null,
        'attemptCount': 0,
      });
    } catch (e) {
      debugPrint('LessonProgressService.resetLessonProgress error: $e');
      rethrow;
    }
  }
}
