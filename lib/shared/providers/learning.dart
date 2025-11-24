import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vcroad_v2/shared/models/lesson.dart';
import 'package:vcroad_v2/shared/models/lesson_progress.dart';
import 'package:vcroad_v2/shared/models/question.dart';
import 'package:vcroad_v2/shared/services/lesson.dart';
import 'package:vcroad_v2/shared/services/lesson_progress.dart';

class LearningProvider with ChangeNotifier {
  final LessonService _lessonService = LessonService.instance;
  final LessonProgressService _progressService = LessonProgressService.instance;

  List<QuizMaterial> _lessons = [];
  List<LessonProgress> _progressList = [];
  UserLearningStats? _stats;
  // Timer / time-limit support
  Timer? _lessonTimer;
  DateTime? _lessonEndTime;
  int _remainingSeconds = 0;

  // cached mapping to avoid rebuilding on every UI call
  Map<QuizMaterial, LessonProgress?> _lessonsWithProgressCache = {};

  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  // Current lesson being taken
  QuizMaterial? _currentLesson;
  LessonProgress? _currentProgress;
  int _currentQuestionIndex = 0;

  // Getters
  List<QuizMaterial> get lessons => _lessons;
  List<LessonProgress> get progressList => _progressList;
  UserLearningStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  QuizMaterial? get currentLesson => _currentLesson;
  LessonProgress? get currentProgress => _currentProgress;
  int get currentQuestionIndex => _currentQuestionIndex;
  QuizQuestion? get currentQuestion =>
      _currentLesson != null &&
          _currentQuestionIndex < _currentLesson!.questions.length
      ? _currentLesson!.questions[_currentQuestionIndex]
      : null;

  // Time-limit getters
  int get currentRemainingSeconds => _remainingSeconds;
  bool get hasTimeLimit => _lessonEndTime != null;
  bool get isTimeExpired => hasTimeLimit && _remainingSeconds <= 0;
  String get remainingFormatted {
    final s = _remainingSeconds.clamp(0, _remainingSeconds);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  bool get isLessonComplete =>
      _currentLesson != null &&
      _currentQuestionIndex >= _currentLesson!.questions.length;

  // Helper to rebuild cache when lessons or progress change
  void _updateLessonsWithProgressCache() {
    final map = <QuizMaterial, LessonProgress?>{};
    final now = DateTime.now();
    for (final lesson in _lessons) {
      final idx = _progressList.indexWhere((p) => p.lessonId == lesson.id);
      if (idx != -1) {
        map[lesson] = _progressList[idx];
      } else {
        // lightweight fallback progress (no heavy logging)
        map[lesson] = LessonProgress(
          id: '${_currentUserId}_${lesson.id}',
          userId: _currentUserId ?? '',
          lessonId: lesson.id,
          chapterCategory: lesson.chapterCategory,
          chapterOrder: lesson.chapterOrder,
          lessonNumber: lesson.lessonNumber,
          totalQuestions: lesson.questionCount,
          totalPoints: lesson.questions.fold(0, (sum, q) => sum + q.points),
          lastAccessedAt: now,
          isLocked: true,
        );
      }
    }
    _lessonsWithProgressCache = map;
    // optional debug summary
    if (kDebugMode) {
      final locked = _lessonsWithProgressCache.values
          .where((p) => p?.isLocked ?? true)
          .length;
      debugPrint('LearningProvider: lessons=${_lessons.length} locked=$locked');
    }
  }

  // Get lesson with its progress
  Map<QuizMaterial, LessonProgress?> getLessonsWithProgress() {
    // return an unmodifiable view to avoid accidental mutation
    return Map<QuizMaterial, LessonProgress?>.unmodifiable(
      _lessonsWithProgressCache,
    );
  }

  // Initialize for a user
  Future<void> initialize(String userId) async {
    if (_currentUserId == userId && _lessons.isNotEmpty) return;

    _currentUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Initialize progress if first time
      await _progressService.initializeUserProgress(userId);

      // Load lessons and progress
      await Future.wait([
        _loadLessons(),
        _loadProgress(userId),
        _loadStats(userId),
      ]);

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('LearningProvider.initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLessons() async {
    _lessons = await _lessonService.getLessons(publishedOnly: true);
    _lessons.sort((a, b) {
      final orderCompare = a.chapterOrder.compareTo(b.chapterOrder);
      if (orderCompare != 0) return orderCompare;
      return (a.lessonNumber ?? 0).compareTo(b.lessonNumber ?? 0);
    });
    _updateLessonsWithProgressCache();
  }

  Future<void> _loadProgress(String userId) async {
    _progressList = await _progressService.getUserProgress(userId);
    _updateLessonsWithProgressCache();
  }

  Future<void> _loadStats(String userId) async {
    try {
      final s = await _progressService.getUserStats(userId);
      _stats = s;
      // Notify so UI pieces that depend on stats (eg. LearningStatsHeader) update.
      notifyListeners();
    } catch (e) {
      debugPrint('LearningProvider._loadStats error: $e');
    }
  }

  // Start a lesson
  Future<bool> startLesson(String lessonId) async {
    if (_currentUserId == null) return false;

    try {
      final lesson = _lessons.firstWhere((l) => l.id == lessonId);
      final progress = _progressList.firstWhere(
        (p) => p.lessonId == lessonId,
        orElse: () => throw Exception('Progress not found'),
      );

      if (progress.isLocked) {
        _error = 'This lesson is locked. Complete previous lessons first.';
        notifyListeners();
        return false;
      }

      _currentLesson = lesson;
      _currentProgress = progress;
      _currentQuestionIndex = 0;

      await _progressService.startLesson(_currentUserId!, lessonId);

      // Refresh the currentProgress so UI reflects new startedAt/attemptCount immediately
      final refreshed = await _progressService.getLessonProgress(
        _currentUserId!,
        lessonId,
      );
      if (refreshed != null) {
        _currentProgress = refreshed;
        final idx = _progressList.indexWhere((p) => p.lessonId == lessonId);
        if (idx != -1) _progressList[idx] = refreshed;
        _updateLessonsWithProgressCache();
      }

      // Start client-side countdown using persisted startedAt + lesson.durationMinutes
      _startLessonTimerIfNeeded(lesson, _currentProgress?.startedAt);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('LearningProvider.startLesson error: $e');
      notifyListeners();
      return false;
    }
  }

  void _startLessonTimerIfNeeded(QuizMaterial lesson, DateTime? startedAt) {
    _lessonTimer?.cancel();
    _lessonEndTime = null;
    _remainingSeconds = 0;

    if (lesson.durationMinutes > 0 && startedAt != null) {
      _lessonEndTime = startedAt.add(Duration(minutes: lesson.durationMinutes));
      _updateRemainingSeconds();
      _lessonTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final prev = _remainingSeconds;
        _updateRemainingSeconds();
        if (_remainingSeconds != prev) notifyListeners();
        if (_remainingSeconds <= 0) {
          _lessonTimer?.cancel();
          // Best-effort finalize when time expires
          unawaited(completeLesson());
        }
      });
    }
  }

  void _updateRemainingSeconds() {
    if (_lessonEndTime == null) {
      _remainingSeconds = 0;
      return;
    }
    final rem = _lessonEndTime!.difference(DateTime.now()).inSeconds;
    _remainingSeconds = rem > 0 ? rem : 0;
  }

  void _stopLessonTimer() {
    _lessonTimer?.cancel();
    _lessonTimer = null;
    _lessonEndTime = null;
    _remainingSeconds = 0;
  }

  // Submit answer for current question
  Future<bool> submitAnswer(dynamic userAnswer) async {
    if (_currentUserId == null ||
        _currentLesson == null ||
        _currentProgress == null ||
        currentQuestion == null) {
      return false;
    }

    // Prevent submissions after time expired
    if (isTimeExpired) {
      // Ensure finalization happens if time already expired
      await completeLesson();
      return false;
    }

    try {
      final question = currentQuestion!;
      final isCorrect = _checkAnswer(question, userAnswer);

      await _progressService.submitAnswer(
        userId: _currentUserId!,
        lessonId: _currentLesson!.id,
        question: question,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
      );

      // Reload progress
      _currentProgress = await _progressService.getLessonProgress(
        _currentUserId!,
        _currentLesson!.id,
      );

      // Update progress list
      final index = _progressList.indexWhere(
        (p) => p.lessonId == _currentLesson!.id,
      );
      if (index != -1 && _currentProgress != null) {
        _progressList[index] = _currentProgress!;
        _updateLessonsWithProgressCache();
      }

      // Refresh aggregated stats in background (non-blocking). _loadStats will notify when done.
      unawaited(_loadStats(_currentUserId!));

      notifyListeners();
      return isCorrect;
    } catch (e) {
      _error = e.toString();
      debugPrint('LearningProvider.submitAnswer error: $e');
      notifyListeners();
      return false;
    }
  }

  bool _checkAnswer(QuizQuestion question, dynamic userAnswer) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        return userAnswer == question.correctIndex;
      case QuestionType.trueFalse:
        return userAnswer == question.correctBool;
      case QuestionType.identification:
        return userAnswer.toString().trim().toLowerCase() ==
            question.correctAnswer?.trim().toLowerCase();
      case QuestionType.matchingType:
        // userAnswer should be Map<String, String> (imageId -> meaningId)
        if (userAnswer is! Map) return false;
        final userMap = Map<String, String>.from(userAnswer);
        for (final pair in question.matchingPairs!) {
          if (userMap[pair.id] != pair.id) return false;
        }
        return true;
    }
  }

  // Move to next question
  void nextQuestion() {
    if (_currentLesson != null &&
        _currentQuestionIndex < _currentLesson!.questions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  bool _isCompleting = false;
  bool get isCompleting => _isCompleting;

  // Complete current lesson
  Future<bool> completeLesson() async {
    if (_currentUserId == null || _currentLesson == null) return false;

    // If already completing, ignore duplicate calls
    if (_isCompleting) return false;

    try {
      // Fast-path: if already completed on client progress, just set UI completed state
      if (_currentProgress?.isCompleted ?? false) {
        _currentQuestionIndex = _currentLesson!.questions.length;
        notifyListeners();
        return true;
      }

      _isCompleting = true;
      notifyListeners();

      // The service returns void/does its own transaction. Await it but do not
      // treat it as a boolean value (avoids use_of_void_result).
      await _progressService.completeLesson(
        _currentUserId!,
        _currentLesson!.id,
      );

      // Refresh the specific lesson progress so LessonResult reads latest values
      _currentProgress = await _progressService.getLessonProgress(
        _currentUserId!,
        _currentLesson!.id,
      );

      // Move index past last question so isLessonComplete becomes true
      _currentQuestionIndex = _currentLesson!.questions.length;

      // Reload lists/stats (do not overwrite _currentProgress)
      await Future.wait([
        _loadProgress(_currentUserId!),
        _loadStats(_currentUserId!),
      ]);

      _isCompleting = false;
      // stop any running timer
      _stopLessonTimer();
      notifyListeners(); // UI will rebuild and LessonViewer will show LessonResult
      return true;
    } catch (e) {
      _isCompleting = false;
      _error = e.toString();
      _stopLessonTimer();
      notifyListeners();
      return false;
    }
  }

  // Exit current lesson
  void exitLesson() {
    _currentLesson = null;
    _currentProgress = null;
    _currentQuestionIndex = 0;
    _stopLessonTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopLessonTimer();
    super.dispose();
  }

  // Refresh data
  Future<void> refresh() async {
    if (_currentUserId == null) return;
    await initialize(_currentUserId!);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
