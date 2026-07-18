// lib/shared/models/lesson.dart
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vcroad/data/models/question.dart';

class QuizMaterial {
  final String id;
  final String chapterCategory;
  final int chapterOrder;
  final String title;
  final String description;
  final UnmodifiableListView<QuizQuestion> questions;
  final int? lessonNumber;

  // Audit info
  final Timestamp createdAt;
  final String createdBy;
  final Timestamp? updatedAt;
  final String? updatedBy;

  // Add these new fields for better management
  final bool isPublished; // Draft vs published state
  final int durationMinutes; // Estimated completion time
  final String? thumbnailUrl; // Optional lesson thumbnail
  final List<String> tags; // Searchable tags

  QuizMaterial({
    required this.id,
    required this.chapterCategory,
    this.chapterOrder = 0,
    required this.title,
    required this.description,
    required List<QuizQuestion> questions,
    this.lessonNumber,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.isPublished = false,
    this.durationMinutes = 10,
    this.thumbnailUrl,
    List<String>? tags,
  }) : questions = UnmodifiableListView(questions),
       tags = tags ?? [];

  // Computed properties for UI
  int get questionCount => questions.length;

  String get displayTitle => '$chapterCategory - $title';

  Map<QuestionType, int> get questionTypeBreakdown {
    final breakdown = <QuestionType, int>{};
    for (final q in questions) {
      breakdown[q.type] = (breakdown[q.type] ?? 0) + 1;
    }
    return breakdown;
  }

  QuizMaterial copyWith({
    String? id,
    String? chapterCategory,
    int? chapterOrder,
    String? title,
    String? description,
    List<QuizQuestion>? questions,
    int? lessonNumber,
    Timestamp? createdAt,
    String? createdBy,
    Timestamp? updatedAt,
    String? updatedBy,
    bool? isPublished,
    int? durationMinutes,
    String? thumbnailUrl,
    List<String>? tags,
  }) {
    return QuizMaterial(
      id: id ?? this.id,
      chapterCategory: chapterCategory ?? this.chapterCategory,
      chapterOrder: chapterOrder ?? this.chapterOrder,
      title: title ?? this.title,
      description: description ?? this.description,
      questions: questions ?? this.questions.toList(),
      lessonNumber: lessonNumber ?? this.lessonNumber,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isPublished: isPublished ?? this.isPublished,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterCategory': chapterCategory,
      'chapterOrder': chapterOrder,
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toJson()).toList(growable: false),
      'lessonNumber': lessonNumber,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
      'isPublished': isPublished,
      'durationMinutes': durationMinutes,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'tags': tags,
    };
  }

  factory QuizMaterial.fromJson(Map<String, dynamic> json) {
    return QuizMaterial(
      id: json['id'] as String,
      chapterCategory: json['chapterCategory'] as String,
      chapterOrder: (json['chapterOrder'] as num?)?.toInt() ?? 0,
      title: json['title'] as String,
      description: json['description'] as String,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => QuizQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList(),
      lessonNumber: (json['lessonNumber'] as num?)?.toInt(),
      createdAt: json['createdAt'] is Timestamp
          ? json['createdAt']
          : Timestamp.now(),
      createdBy: json['createdBy'] as String,
      updatedAt: json['updatedAt'] as Timestamp?,
      updatedBy: json['updatedBy'] as String?,
      isPublished: (json['isPublished'] as bool?) ?? false,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 10,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList(),
    );
  }
}

// Helper class for grouping lessons by chapter
class ChapterGroup {
  final String category;
  final List<QuizMaterial> lessons;

  ChapterGroup({required this.category, required this.lessons});

  int get totalLessons => lessons.length;
  int get totalQuestions =>
      lessons.fold(0, (total, l) => total + l.questionCount);
  // Sort lessons by chapterOrder and lessonNumber
  void sortLessons() {
    lessons.sort((a, b) {
      final orderCompare = a.chapterOrder.compareTo(b.chapterOrder);
      if (orderCompare != 0) return orderCompare;
      return (a.lessonNumber ?? 0).compareTo(b.lessonNumber ?? 0);
    });
  }
}

class ChapterMetadata {
  final String category;
  final int chapterOrder;
  final int nextLessonNumber;
  final bool exists; // true if category already exists

  const ChapterMetadata({
    required this.category,
    required this.chapterOrder,
    required this.nextLessonNumber,
    required this.exists,
  });
}

class ChapterInfo {
  final String category;
  final int chapterOrder;
  final int lessonCount;
  final int maxLessonNumber;

  const ChapterInfo({
    required this.category,
    required this.chapterOrder,
    required this.lessonCount,
    required this.maxLessonNumber,
  });

  int get nextLessonNumber => maxLessonNumber + 1;
}
