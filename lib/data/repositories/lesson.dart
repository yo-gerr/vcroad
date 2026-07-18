import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'dart:math';

class LessonService {
  LessonService._();
  static final LessonService instance = LessonService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'lessons';
  // Get all lessons, optionally filtered
  Future<List<QuizMaterial>> getLessons({
    String? category,
    bool? publishedOnly,
    String? createdBy,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .orderBy('chapterOrder')
          .orderBy('lessonNumber');

      if (category != null && category.isNotEmpty) {
        query = query.where('chapterCategory', isEqualTo: category);
      }

      if (publishedOnly == true) {
        query = query.where('isPublished', isEqualTo: true);
      }

      if (createdBy != null && createdBy.isNotEmpty) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => QuizMaterial.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('LessonService.getLessons error: $e');
      rethrow;
    }
  }

  // Get lessons grouped by chapter
  Future<List<ChapterGroup>> getLessonsGroupedByChapter({
    bool? publishedOnly,
  }) async {
    final lessons = await getLessons(publishedOnly: publishedOnly);
    final groups = <String, List<QuizMaterial>>{};

    for (final lesson in lessons) {
      groups.putIfAbsent(lesson.chapterCategory, () => []).add(lesson);
    }

    final result = groups.entries
        .map((e) => ChapterGroup(category: e.key, lessons: e.value))
        .toList();

    // Sort each chapter's lessons
    for (final group in result) {
      group.sortLessons();
    }

    // Sort chapters by numeric chapterOrder (use min chapterOrder in each group).
    // This keeps author-defined ordering instead of alphabetical.
    result.sort((a, b) {
      final aOrder = a.lessons.isNotEmpty
          ? a.lessons.map((l) => l.chapterOrder).reduce(min)
          : 0;
      final bOrder = b.lessons.isNotEmpty
          ? b.lessons.map((l) => l.chapterOrder).reduce(min)
          : 0;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      return a.category.compareTo(b.category);
    });

    return result;
  }

  // Get single lesson by ID
  Future<QuizMaterial?> getLesson(String lessonId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(lessonId).get();
      if (!doc.exists) return null;
      return QuizMaterial.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('LessonService.getLesson error: $e');
      return null;
    }
  }

  // Create new lesson
  Future<String> createLesson(QuizMaterial lesson) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to create lessons');
      }

      final docRef = _firestore.collection(_collection).doc();
      final now = Timestamp.now();

      var lessonWithAudit = lesson.copyWith(
        id: docRef.id,
        createdAt: now,
        createdBy: currentUser.uid,
        updatedAt: now,
        updatedBy: currentUser.uid,
      );

      // Commented out: uploadLessonImages uses firebase_storage
      // lessonWithAudit = await _imageService.uploadLessonImages(lessonWithAudit);

      await docRef.set(lessonWithAudit.toJson());
      return docRef.id;
    } catch (e) {
      debugPrint('LessonService.createLesson error: $e');
      rethrow;
    }
  }

  // Update existing lesson
  Future<void> updateLesson(QuizMaterial lesson) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to update lessons');
      }

      var lessonWithAudit = lesson.copyWith(
        updatedAt: Timestamp.now(),
        updatedBy: currentUser.uid,
      );

      // Save lesson directly without image upload
      await _firestore
          .collection(_collection)
          .doc(lessonWithAudit.id)
          .set(lessonWithAudit.toJson());
    } catch (e) {
      debugPrint('LessonService.updateLesson error: $e');
      rethrow;
    }
  }

  // Delete lesson
  Future<void> deleteLesson(String lessonId) async {
    try {
      // Commented out: deleteLessonImages uses firebase_storage
      // await _imageService.deleteLessonImages(lessonId);

      // Then delete document
      await _firestore.collection(_collection).doc(lessonId).delete();
    } catch (e) {
      debugPrint('LessonService.deleteLesson error: $e');
      rethrow;
    }
  }

  // Reorder lessons within a chapter
  Future<void> reorderLessons(List<QuizMaterial> lessons) async {
    try {
      final batch = _firestore.batch();
      final currentUser = FirebaseAuth.instance.currentUser;
      final now = Timestamp.now();

      for (int i = 0; i < lessons.length; i++) {
        final lesson = lessons[i].copyWith(
          chapterOrder: i,
          lessonNumber: i + 1,
          updatedAt: now,
          updatedBy: currentUser?.uid,
        );

        batch.set(
          _firestore.collection(_collection).doc(lesson.id),
          lesson.toJson(),
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint('LessonService.reorderLessons error: $e');
      rethrow;
    }
  }

  // Get distinct chapter categories
  Future<List<String>> getChapterCategories() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final categories = snapshot.docs
          .map((doc) => doc.data()['chapterCategory'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      categories.sort();
      return categories;
    } catch (e) {
      debugPrint('LessonService.getChapterCategories error: $e');
      return [];
    }
  }

  // Publish/unpublish lesson
  Future<void> togglePublishStatus(String lessonId, bool publish) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await _firestore.collection(_collection).doc(lessonId).update({
        'isPublished': publish,
        'updatedAt': Timestamp.now(),
        'updatedBy': currentUser?.uid,
      });
    } catch (e) {
      debugPrint('LessonService.togglePublishStatus error: $e');
      rethrow;
    }
  }

  // Get next available chapter order for a new category
  Future<int> getNextChapterOrder() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('chapterOrder', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0;
      final maxOrder =
          (snapshot.docs.first.data()['chapterOrder'] as num?)?.toInt() ?? 0;
      return maxOrder + 1;
    } catch (e) {
      debugPrint('LessonService.getNextChapterOrder error: $e');
      return 0;
    }
  }

  // Get chapter metadata (order and next lesson number) for a category
  Future<ChapterMetadata> getChapterMetadata(String category) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('chapterCategory', isEqualTo: category)
          .orderBy('lessonNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Category doesn't exist yet, return next available chapter order
        final nextOrder = await getNextChapterOrder();
        return ChapterMetadata(
          category: category,
          chapterOrder: nextOrder,
          nextLessonNumber: 1,
          exists: false,
        );
      }

      final doc = snapshot.docs.first.data();
      final chapterOrder = (doc['chapterOrder'] as num?)?.toInt() ?? 0;
      final maxLessonNumber = (doc['lessonNumber'] as num?)?.toInt() ?? 0;

      return ChapterMetadata(
        category: category,
        chapterOrder: chapterOrder,
        nextLessonNumber: maxLessonNumber + 1,
        exists: true,
      );
    } catch (e) {
      debugPrint('LessonService.getChapterMetadata error: $e');
      return ChapterMetadata(
        category: category,
        chapterOrder: 0,
        nextLessonNumber: 1,
        exists: false,
      );
    }
  }

  // Get all existing chapter categories with their orders
  Future<List<ChapterInfo>> getChapterInfoList() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('chapterOrder')
          .get();

      final Map<String, ChapterInfo> categoryMap = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final category = data['chapterCategory'] as String?;
        final order = (data['chapterOrder'] as num?)?.toInt() ?? 0;
        final lessonNum = (data['lessonNumber'] as num?)?.toInt() ?? 0;

        if (category != null) {
          if (!categoryMap.containsKey(category)) {
            categoryMap[category] = ChapterInfo(
              category: category,
              chapterOrder: order,
              lessonCount: 1,
              maxLessonNumber: lessonNum,
            );
          } else {
            final existing = categoryMap[category]!;
            categoryMap[category] = ChapterInfo(
              category: category,
              chapterOrder: order,
              lessonCount: existing.lessonCount + 1,
              maxLessonNumber: max(existing.maxLessonNumber, lessonNum),
            );
          }
        }
      }

      return categoryMap.values.toList()
        ..sort((a, b) => a.chapterOrder.compareTo(b.chapterOrder));
    } catch (e) {
      debugPrint('LessonService.getChapterInfoList error: $e');
      return [];
    }
  }
}
