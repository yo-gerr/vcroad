import 'package:cloud_firestore/cloud_firestore.dart';

enum LessonStatus { locked, available, inProgress, completed }

class QuestionAttempt {
  final String questionId;
  final String? userAnswer;
  final bool isCorrect;
  final int pointsEarned;
  final DateTime attemptedAt;

  QuestionAttempt({
    required this.questionId,
    this.userAnswer,
    required this.isCorrect,
    required this.pointsEarned,
    required this.attemptedAt,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'userAnswer': userAnswer,
    'isCorrect': isCorrect,
    'pointsEarned': pointsEarned,
    'attemptedAt': Timestamp.fromDate(attemptedAt),
  };

  factory QuestionAttempt.fromJson(Map<String, dynamic> json) {
    return QuestionAttempt(
      questionId: json['questionId'] as String,
      userAnswer: json['userAnswer'] as String?,
      isCorrect: json['isCorrect'] as bool,
      pointsEarned: (json['pointsEarned'] as num).toInt(),
      attemptedAt: (json['attemptedAt'] as Timestamp).toDate(),
    );
  }
}

class LessonProgress {
  final String id;
  final String userId;
  final String lessonId;
  final String chapterCategory;
  final int chapterOrder;
  final int? lessonNumber;

  final bool isCompleted;
  final bool isLocked;
  final int questionsAnswered;
  final int questionsCorrect;
  final int totalQuestions;
  final int pointsEarned;
  final int totalPoints;
  final double scorePercentage;

  final List<QuestionAttempt> attempts;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime lastAccessedAt;
  final int attemptCount;

  LessonProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.chapterCategory,
    required this.chapterOrder,
    this.lessonNumber,
    this.isCompleted = false,
    this.isLocked = true,
    this.questionsAnswered = 0,
    this.questionsCorrect = 0,
    required this.totalQuestions,
    this.pointsEarned = 0,
    required this.totalPoints,
    this.scorePercentage = 0.0,
    List<QuestionAttempt>? attempts,
    this.startedAt,
    this.completedAt,
    required this.lastAccessedAt,
    this.attemptCount = 0,
  }) : attempts = attempts ?? [];

  LessonStatus get status {
    if (isLocked) return LessonStatus.locked;
    if (isCompleted) return LessonStatus.completed;
    if (questionsAnswered > 0) return LessonStatus.inProgress;
    return LessonStatus.available;
  }

  bool get isPassed => scorePercentage >= 70.0; // 70% passing grade

  LessonProgress copyWith({
    String? id,
    String? userId,
    String? lessonId,
    String? chapterCategory,
    int? chapterOrder,
    int? lessonNumber,
    bool? isCompleted,
    bool? isLocked,
    int? questionsAnswered,
    int? questionsCorrect,
    int? totalQuestions,
    int? pointsEarned,
    int? totalPoints,
    double? scorePercentage,
    List<QuestionAttempt>? attempts,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? lastAccessedAt,
    int? attemptCount,
  }) {
    return LessonProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      chapterCategory: chapterCategory ?? this.chapterCategory,
      chapterOrder: chapterOrder ?? this.chapterOrder,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      isCompleted: isCompleted ?? this.isCompleted,
      isLocked: isLocked ?? this.isLocked,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      questionsCorrect: questionsCorrect ?? this.questionsCorrect,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      totalPoints: totalPoints ?? this.totalPoints,
      scorePercentage: scorePercentage ?? this.scorePercentage,
      attempts: attempts ?? this.attempts,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'lessonId': lessonId,
    'chapterCategory': chapterCategory,
    'chapterOrder': chapterOrder,
    'lessonNumber': lessonNumber,
    'isCompleted': isCompleted,
    'isLocked': isLocked,
    'questionsAnswered': questionsAnswered,
    'questionsCorrect': questionsCorrect,
    'totalQuestions': totalQuestions,
    'pointsEarned': pointsEarned,
    'totalPoints': totalPoints,
    'scorePercentage': scorePercentage,
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
    'lastAccessedAt': Timestamp.fromDate(lastAccessedAt),
    'attemptCount': attemptCount,
  };

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      id: json['id'] as String,
      userId: json['userId'] as String,
      lessonId: json['lessonId'] as String,
      chapterCategory: json['chapterCategory'] as String,
      chapterOrder: (json['chapterOrder'] as num).toInt(),
      lessonNumber: (json['lessonNumber'] as num?)?.toInt(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? true,
      questionsAnswered: (json['questionsAnswered'] as num?)?.toInt() ?? 0,
      questionsCorrect: (json['questionsCorrect'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      totalPoints: (json['totalPoints'] as num).toInt(),
      scorePercentage: (json['scorePercentage'] as num?)?.toDouble() ?? 0.0,
      attempts:
          (json['attempts'] as List<dynamic>?)
              ?.map((a) => QuestionAttempt.fromJson(a))
              .toList() ??
          [],
      startedAt: json['startedAt'] != null
          ? (json['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] as Timestamp).toDate()
          : null,
      lastAccessedAt: (json['lastAccessedAt'] as Timestamp).toDate(),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserLearningStats {
  final int totalLessonsAvailable;
  final int lessonsCompleted;
  final int lessonsInProgress;
  final int totalPointsEarned;
  final int totalPointsAvailable;
  final double overallProgress;
  final int currentStreak;
  final DateTime? lastActivityDate;

  UserLearningStats({
    required this.totalLessonsAvailable,
    required this.lessonsCompleted,
    required this.lessonsInProgress,
    required this.totalPointsEarned,
    required this.totalPointsAvailable,
    required this.overallProgress,
    this.currentStreak = 0,
    this.lastActivityDate,
  });

  double get completionRate => totalLessonsAvailable > 0
      ? (lessonsCompleted / totalLessonsAvailable) * 100
      : 0.0;
}
