import 'package:cloud_firestore/cloud_firestore.dart';

class Lesson {
  final String id;
  final String title;
  final String description;
  final String chapterId;
  final int lessonNumber;
  final bool isPublished;
  final int durationMinutes;
  final String? thumbnailUrl;
  final List<String> tags;
  final int pointsAvailable;

  final Timestamp createdAt;
  final String createdBy;
  final Timestamp? updatedAt;
  final String? updatedBy;

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.chapterId,
    this.lessonNumber = 1,
    this.isPublished = false,
    this.durationMinutes = 10,
    this.thumbnailUrl,
    List<String>? tags,
    this.pointsAvailable = 0,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  }) : tags = tags ?? [];

  int get totalPoints => pointsAvailable;

  String get displayTitle => '$chapterId - $title';

  Lesson copyWith({
    String? id,
    String? title,
    String? description,
    String? chapterId,
    int? lessonNumber,
    bool? isPublished,
    int? durationMinutes,
    String? thumbnailUrl,
    List<String>? tags,
    int? pointsAvailable,
    Timestamp? createdAt,
    String? createdBy,
    Timestamp? updatedAt,
    String? updatedBy,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      chapterId: chapterId ?? this.chapterId,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      isPublished: isPublished ?? this.isPublished,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      tags: tags ?? this.tags,
      pointsAvailable: pointsAvailable ?? this.pointsAvailable,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'chapterId': chapterId,
      'lessonNumber': lessonNumber,
      'isPublished': isPublished,
      'durationMinutes': durationMinutes,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'tags': tags,
      'pointsAvailable': pointsAvailable,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      chapterId: json['chapterId'] as String,
      lessonNumber: (json['lessonNumber'] as num?)?.toInt() ?? 1,
      isPublished: (json['isPublished'] as bool?) ?? false,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 10,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      pointsAvailable: (json['pointsAvailable'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] is Timestamp
          ? json['createdAt']
          : Timestamp.now(),
      createdBy: json['createdBy'] as String,
      updatedAt: json['updatedAt'] as Timestamp?,
      updatedBy: json['updatedBy'] as String?,
    );
  }
}

class Chapter {
  final String id;
  final String name;
  final int order;
  final String? description;
  final int lessonCount;

  const Chapter({
    required this.id,
    required this.name,
    required this.order,
    this.description,
    this.lessonCount = 0,
  });

  Chapter copyWith({
    String? id,
    String? name,
    int? order,
    String? description,
    int? lessonCount,
  }) {
    return Chapter(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      description: description ?? this.description,
      lessonCount: lessonCount ?? this.lessonCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'order': order,
    if (description != null) 'description': description,
    'lessonCount': lessonCount,
  };

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String? ?? json['name'] as String,
      name: json['name'] as String,
      order: (json['order'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      lessonCount: (json['lessonCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChapterGroup {
  final Chapter chapter;
  final List<Lesson> lessons;

  ChapterGroup({required this.chapter, required this.lessons});

  int get totalLessons => lessons.length;
  int get totalPoints =>
      lessons.fold(0, (total, l) => total + l.pointsAvailable);
}

class ChapterMetadata {
  final String category;
  final int chapterOrder;
  final int nextLessonNumber;
  final bool exists;

  const ChapterMetadata({
    required this.category,
    required this.chapterOrder,
    required this.nextLessonNumber,
    required this.exists,
  });
}
