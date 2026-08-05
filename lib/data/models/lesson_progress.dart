import 'package:cloud_firestore/cloud_firestore.dart';

enum LessonStatus { locked, available, inProgress, completed }

class QuestionAttempt {
  final String questionId;
  final String? userAnswer;
  final bool isCorrect;
  final int pointsEarned;
  final DateTime attemptedAt;
  final DateTime? nextReviewAt;
  final int interval;

  QuestionAttempt({
    required this.questionId,
    this.userAnswer,
    required this.isCorrect,
    required this.pointsEarned,
    required this.attemptedAt,
    this.nextReviewAt,
    this.interval = 0,
  });

  QuestionAttempt copyWith({
    String? questionId,
    String? userAnswer,
    bool? isCorrect,
    int? pointsEarned,
    DateTime? attemptedAt,
    DateTime? nextReviewAt,
    int? interval,
  }) {
    return QuestionAttempt(
      questionId: questionId ?? this.questionId,
      userAnswer: userAnswer ?? this.userAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      attemptedAt: attemptedAt ?? this.attemptedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      interval: interval ?? this.interval,
    );
  }

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'userAnswer': userAnswer,
    'isCorrect': isCorrect,
    'pointsEarned': pointsEarned,
    'attemptedAt': Timestamp.fromDate(attemptedAt),
    if (nextReviewAt != null) 'nextReviewAt': Timestamp.fromDate(nextReviewAt!),
    'interval': interval,
  };

  factory QuestionAttempt.fromJson(Map<String, dynamic> json) {
    return QuestionAttempt(
      questionId: json['questionId'] as String,
      userAnswer: json['userAnswer'] as String?,
      isCorrect: json['isCorrect'] as bool,
      pointsEarned: (json['pointsEarned'] as num).toInt(),
      attemptedAt: (json['attemptedAt'] as Timestamp).toDate(),
      nextReviewAt: (json['nextReviewAt'] as Timestamp?)?.toDate(),
      interval: (json['interval'] as num?)?.toInt() ?? 0,
    );
  }
}

class LessonProgress {
  final String id;
  final String userId;
  final String lessonId;
  final String chapterId;
  final int? lessonNumber;

  final bool isCompleted;
  final bool isLocked;
  final double score;
  final int questionsAnswered;
  final int questionsCorrect;
  final int totalQuestions;
  final int pointsEarned;
  final int totalPoints;
  final int attemptCount;

  final List<QuestionAttempt> attempts;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime lastAccessedAt;
  final DateTime? nextReviewAt;
  final List<String> badges;
  final int reviewCount;

  LessonProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.chapterId,
    this.lessonNumber,
    this.isCompleted = false,
    this.isLocked = true,
    this.score = 0.0,
    this.questionsAnswered = 0,
    this.questionsCorrect = 0,
    required this.totalQuestions,
    this.pointsEarned = 0,
    required this.totalPoints,
    this.attemptCount = 0,
    List<QuestionAttempt>? attempts,
    this.startedAt,
    this.completedAt,
    required this.lastAccessedAt,
    this.nextReviewAt,
    List<String>? badges,
    this.reviewCount = 0,
  }) : attempts = attempts ?? [],
       badges = badges ?? [];

  LessonStatus get status {
    if (isLocked) return LessonStatus.locked;
    if (isCompleted) return LessonStatus.completed;
    if (questionsAnswered > 0) return LessonStatus.inProgress;
    return LessonStatus.available;
  }

  bool get isPassed => score >= 70.0;

  bool get isDueForReview =>
      !isLocked &&
      isCompleted &&
      nextReviewAt != null &&
      nextReviewAt!.isBefore(DateTime.now());

  LessonProgress copyWith({
    String? id,
    String? userId,
    String? lessonId,
    String? chapterId,
    int? lessonNumber,
    bool? isCompleted,
    bool? isLocked,
    double? score,
    int? questionsAnswered,
    int? questionsCorrect,
    int? totalQuestions,
    int? pointsEarned,
    int? totalPoints,
    int? attemptCount,
    List<QuestionAttempt>? attempts,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? lastAccessedAt,
    DateTime? nextReviewAt,
    List<String>? badges,
    int? reviewCount,
  }) {
    return LessonProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      chapterId: chapterId ?? this.chapterId,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      isCompleted: isCompleted ?? this.isCompleted,
      isLocked: isLocked ?? this.isLocked,
      score: score ?? this.score,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      questionsCorrect: questionsCorrect ?? this.questionsCorrect,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      totalPoints: totalPoints ?? this.totalPoints,
      attemptCount: attemptCount ?? this.attemptCount,
      attempts: attempts ?? this.attempts,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      badges: badges ?? this.badges,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'lessonId': lessonId,
    'chapterId': chapterId,
    'lessonNumber': lessonNumber,
    'isCompleted': isCompleted,
    'isLocked': isLocked,
    'score': score,
    'questionsAnswered': questionsAnswered,
    'questionsCorrect': questionsCorrect,
    'totalQuestions': totalQuestions,
    'pointsEarned': pointsEarned,
    'totalPoints': totalPoints,
    'attemptCount': attemptCount,
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
    'lastAccessedAt': Timestamp.fromDate(lastAccessedAt),
    if (nextReviewAt != null)
      'nextReviewAt': Timestamp.fromDate(nextReviewAt!),
    'badges': badges,
    'reviewCount': reviewCount,
  };

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      id: json['id'] as String,
      userId: json['userId'] as String,
      lessonId: json['lessonId'] as String,
      chapterId: (json['chapterId'] as String?) ?? '',
      lessonNumber: (json['lessonNumber'] as num?)?.toInt(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? true,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      questionsAnswered: (json['questionsAnswered'] as num?)?.toInt() ?? 0,
      questionsCorrect: (json['questionsCorrect'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num).toInt(),
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      totalPoints: (json['totalPoints'] as num).toInt(),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
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
      nextReviewAt: json['nextReviewAt'] != null
          ? (json['nextReviewAt'] as Timestamp).toDate()
          : null,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((b) => b.toString())
              .toList() ??
          [],
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserLearningStats {
  final int completedLessons;
  final int totalPointsEarned;
  final int totalPointsAvailable;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final int xp;
  final int level;

  UserLearningStats({
    this.completedLessons = 0,
    this.totalPointsEarned = 0,
    this.totalPointsAvailable = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    this.xp = 0,
    this.level = 1,
  });

  double get completionRate => totalPointsAvailable > 0
      ? (totalPointsEarned / totalPointsAvailable) * 100
      : 0.0;

  Map<String, dynamic> toJson() => {
    'completedLessons': completedLessons,
    'totalPointsEarned': totalPointsEarned,
    'totalPointsAvailable': totalPointsAvailable,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActivityDate':
        lastActivityDate != null ? Timestamp.fromDate(lastActivityDate!) : null,
    'xp': xp,
    'level': level,
  };

  factory UserLearningStats.fromJson(Map<String, dynamic> json) {
    return UserLearningStats(
      completedLessons: (json['completedLessons'] as num?)?.toInt() ?? 0,
      totalPointsEarned: (json['totalPointsEarned'] as num?)?.toInt() ?? 0,
      totalPointsAvailable:
          (json['totalPointsAvailable'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastActivityDate:
          (json['lastActivityDate'] as Timestamp?)?.toDate(),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }
}
