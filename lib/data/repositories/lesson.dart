import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/data/repositories/lesson_image.dart';

class LessonService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LessonImageService _imageService;
  final String _lessonsCollection = 'lessons';
  final String _questionsCollection = 'questions';
  final String _chaptersCollection = 'chapters';

  LessonService._({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LessonImageService? imageService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _imageService = imageService ?? LessonImageService.instance;

  static final LessonService instance = LessonService._();

  factory LessonService.withDeps({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LessonImageService? imageService,
  }) {
    return LessonService._(
      firestore: firestore,
      auth: auth,
      imageService: imageService,
    );
  }

  Future<List<Lesson>> getLessons({
    String? chapterId,
    bool? publishedOnly,
    String? createdBy,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_lessonsCollection)
          .orderBy('lessonNumber');

      if (chapterId != null && chapterId.isNotEmpty) {
        query = query.where('chapterId', isEqualTo: chapterId);
      }

      if (publishedOnly == true) {
        query = query.where('isPublished', isEqualTo: true);
      }

      if (createdBy != null && createdBy.isNotEmpty) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Lesson.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('LessonService.getLessons error: $e');
      rethrow;
    }
  }

  Future<List<Lesson>> getLessonsByChapter(String chapterId) async {
    return getLessons(chapterId: chapterId);
  }

  Future<Lesson?> getLesson(String lessonId) async {
    try {
      final doc = await _firestore
          .collection(_lessonsCollection)
          .doc(lessonId)
          .get();
      if (!doc.exists) return null;
      return Lesson.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('LessonService.getLesson error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLessonsMeta({
    String? chapterId,
    bool? publishedOnly,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_lessonsCollection)
          .orderBy('lessonNumber');

      if (chapterId != null && chapterId.isNotEmpty) {
        query = query.where('chapterId', isEqualTo: chapterId);
      }

      if (publishedOnly == true) {
        query = query.where('isPublished', isEqualTo: true);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': data['id'],
          'title': data['title'],
          'description': data['description'],
          'chapterId': data['chapterId'],
          'lessonNumber': data['lessonNumber'],
          'isPublished': data['isPublished'],
          'durationMinutes': data['durationMinutes'],
          'thumbnailUrl': data['thumbnailUrl'],
          'tags': data['tags'],
          'pointsAvailable': data['pointsAvailable'],
          'createdAt': data['createdAt'],
          'createdBy': data['createdBy'],
          'updatedAt': data['updatedAt'],
          'updatedBy': data['updatedBy'],
        };
      }).toList();
    } catch (e) {
      debugPrint('LessonService.getLessonsMeta error: $e');
      return [];
    }
  }

  Future<String> createLesson(Lesson lesson) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      final docRef = _firestore.collection(_lessonsCollection).doc();
      final now = Timestamp.now();

      final lessonWithAudit = lesson.copyWith(
        id: docRef.id,
        createdAt: now,
        createdBy: currentUser.uid,
        updatedAt: now,
        updatedBy: currentUser.uid,
      );

      final batch = _firestore.batch();
      final docData = lessonWithAudit.toJson();
      batch.set(docRef, docData);
      _adjustChapterLessonCount(batch, lessonWithAudit.chapterId, 1);
      await batch.commit();

      return docRef.id;
    } catch (e) {
      debugPrint('LessonService.createLesson error: $e');
      rethrow;
    }
  }

  Future<void> updateLesson(Lesson lesson) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated');
      }

      final previous = await _firestore
          .collection(_lessonsCollection)
          .doc(lesson.id)
          .get();
      final previousChapterId = (previous.data()?['chapterId'] as String?) ??
          lesson.chapterId;

      final lessonWithAudit = lesson.copyWith(
        updatedAt: Timestamp.now(),
        updatedBy: currentUser.uid,
      );

      final batch = _firestore.batch();
      final docData = lessonWithAudit.toJson();
      batch.set(
        _firestore.collection(_lessonsCollection).doc(lessonWithAudit.id),
        docData,
      );
      if (previousChapterId != lesson.chapterId) {
        if (previousChapterId.isNotEmpty) {
          _adjustChapterLessonCount(batch, previousChapterId, -1);
        }
        _adjustChapterLessonCount(batch, lesson.chapterId, 1);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('LessonService.updateLesson error: $e');
      rethrow;
    }
  }

  Future<void> deleteLesson(String lessonId) async {
    try {
      final lessonDoc = await _firestore
          .collection(_lessonsCollection)
          .doc(lessonId)
          .get();
      final chapterId = (lessonDoc.data()?['chapterId'] as String?) ?? '';

      await _imageService.deleteLessonImages(lessonId);

      final questions = await _firestore
          .collection(_questionsCollection)
          .where('lessonId', isEqualTo: lessonId)
          .get();

      final batch = _firestore.batch();
      for (final q in questions.docs) {
        batch.delete(q.reference);
      }
      batch.delete(_firestore.collection(_lessonsCollection).doc(lessonId));
      if (chapterId.isNotEmpty) {
        _adjustChapterLessonCount(batch, chapterId, -1);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('LessonService.deleteLesson error: $e');
      rethrow;
    }
  }

  Future<void> togglePublishStatus(String lessonId, bool publish) async {
    try {
      final currentUser = _auth.currentUser;
      await _firestore.collection(_lessonsCollection).doc(lessonId).update({
        'isPublished': publish,
        'updatedAt': Timestamp.now(),
        'updatedBy': currentUser?.uid,
      });
    } catch (e) {
      debugPrint('LessonService.togglePublishStatus error: $e');
      rethrow;
    }
  }

  Stream<List<Lesson>> watchLessons({
    String? chapterId,
    bool? publishedOnly,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_lessonsCollection)
        .orderBy('lessonNumber');

    if (chapterId != null && chapterId.isNotEmpty) {
      query = query.where('chapterId', isEqualTo: chapterId);
    }

    if (publishedOnly == true) {
      query = query.where('isPublished', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Lesson.fromJson(doc.data()))
          .toList();
    });
  }

  Future<List<QuizQuestion>> getQuestions(String lessonId) async {
    try {
      final snapshot = await _firestore
          .collection(_questionsCollection)
          .where('lessonId', isEqualTo: lessonId)
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => QuizQuestion.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('LessonService.getQuestions error: $e');
      return [];
    }
  }

  Future<void> saveQuestions({
    required String lessonId,
    required List<QuizQuestion> questions,
  }) async {
    try {
      final existing = await _firestore
          .collection(_questionsCollection)
          .where('lessonId', isEqualTo: lessonId)
          .get();
      final keptIds = questions.map((q) => q.id).toSet();

      final batch = _firestore.batch();
      int totalPoints = 0;

      for (int i = 0; i < questions.length; i++) {
        var q = questions[i];
        totalPoints += q.points;

        final docRef = _firestore
            .collection(_questionsCollection)
            .doc(q.id);

        q = await _imageService.uploadQuestionImages(
          question: q,
          lessonId: lessonId,
        );

        final data = q.toJson();
        data['lessonId'] = lessonId;
        data['order'] = i;

        batch.set(docRef, data, SetOptions(merge: true));
      }

      for (final doc in existing.docs) {
        if (!keptIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      batch.update(
        _firestore.collection(_lessonsCollection).doc(lessonId),
        {'pointsAvailable': totalPoints},
      );

      await batch.commit();
    } catch (e) {
      debugPrint('LessonService.saveQuestions error: $e');
      rethrow;
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    try {
      await _firestore.collection(_questionsCollection).doc(questionId).delete();
    } catch (e) {
      debugPrint('LessonService.deleteQuestion error: $e');
      rethrow;
    }
  }

  Stream<List<QuizQuestion>> watchQuestions(String lessonId) {
    return _firestore
        .collection(_questionsCollection)
        .where('lessonId', isEqualTo: lessonId)
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QuizQuestion.fromJson(doc.data()))
          .toList();
    });
  }

  Future<List<Chapter>> getChapters() async {
    try {
      final [chaptersSnap, lessonsSnap] = await Future.wait([
        _firestore.collection(_chaptersCollection).orderBy('order').get(),
        _firestore.collection(_lessonsCollection).get(),
      ]);

      final counts = <String, int>{};
      for (final doc in lessonsSnap.docs) {
        final chapterId = doc.data()['chapterId'] as String?;
        if (chapterId == null || chapterId.isEmpty) continue;
        counts[chapterId] = (counts[chapterId] ?? 0) + 1;
      }

      return chaptersSnap.docs.map((doc) {
        final chapter = Chapter.fromJson(doc.data());
        return chapter.copyWith(lessonCount: counts[chapter.id] ?? 0);
      }).toList();
    } catch (e) {
      debugPrint('LessonService.getChapters error: $e');
      return [];
    }
  }

  Future<List<ChapterGroup>> getLessonsGroupedByChapter({
    bool? publishedOnly,
  }) async {
    final chapters = await getChapters();
    final lessons = await getLessons(publishedOnly: publishedOnly);

    final Map<String, List<Lesson>> grouped = {};
    for (final l in lessons) {
      grouped.putIfAbsent(l.chapterId, () => []).add(l);
    }

    return chapters.map((chapter) {
      final chapterLessons = grouped[chapter.id] ?? [];
      chapterLessons.sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
      return ChapterGroup(chapter: chapter, lessons: chapterLessons);
    }).toList();
  }

  /// Creates a chapter document. The chapter name is used as the document ID,
  /// so duplicate names are rejected (returns `false`) instead of overwriting.
  Future<bool> createChapter({
    required String name,
    required int order,
    String? description,
  }) async {
    try {
      final docRef = _firestore.collection(_chaptersCollection).doc(name);
      final existing = await docRef.get();
      if (existing.exists) return false;

      final chapter = Chapter(
        id: docRef.id,
        name: name,
        order: order,
        description: description,
      );
      await docRef.set(chapter.toJson());
      return true;
    } catch (e) {
      debugPrint('LessonService.createChapter error: $e');
      rethrow;
    }
  }

  /// Updates a chapter. If `previousName` is provided and differs from the new
  /// name, the chapter document is recreated under the new name and all its
  /// lessons are migrated to the new `chapterId`.
  Future<void> updateChapter(Chapter chapter, {String? previousName}) async {
    try {
      final newId = chapter.id;
      if (previousName != null && previousName != newId) {
        final lessons = await _firestore
            .collection(_lessonsCollection)
            .where('chapterId', isEqualTo: previousName)
            .get();

        final batch = _firestore.batch();
        for (final doc in lessons.docs) {
          batch.update(doc.reference, {'chapterId': newId});
        }
        batch.delete(_firestore.collection(_chaptersCollection).doc(previousName));
        batch.set(_firestore.collection(_chaptersCollection).doc(newId), chapter.toJson());
        await batch.commit();
      } else {
        await _firestore
            .collection(_chaptersCollection)
            .doc(newId)
            .set(chapter.toJson());
      }
    } catch (e) {
      debugPrint('LessonService.updateChapter error: $e');
      rethrow;
    }
  }

  /// Persists the new display order for all chapters in one batch.
  Future<void> updateChapterOrder(List<String> orderedIds) async {
    try {
      final batch = _firestore.batch();
      for (int i = 0; i < orderedIds.length; i++) {
        batch.update(
          _firestore.collection(_chaptersCollection).doc(orderedIds[i]),
          {'order': i},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('LessonService.updateChapterOrder error: $e');
      rethrow;
    }
  }

  /// Deletes a chapter along with all lessons in it and their questions.
  Future<void> deleteChapter(String chapterId) async {
    try {
      final lessons = await _firestore
          .collection(_lessonsCollection)
          .where('chapterId', isEqualTo: chapterId)
          .get();

      final batch = _firestore.batch();
      for (final lessonDoc in lessons.docs) {
        await _imageService.deleteLessonImages(lessonDoc.id);
        final questions = await _firestore
            .collection(_questionsCollection)
            .where('lessonId', isEqualTo: lessonDoc.id)
            .get();
        for (final q in questions.docs) {
          batch.delete(q.reference);
        }
        batch.delete(lessonDoc.reference);
      }
      batch.delete(_firestore.collection(_chaptersCollection).doc(chapterId));
      await batch.commit();
    } catch (e) {
      debugPrint('LessonService.deleteChapter error: $e');
      rethrow;
    }
  }

  Future<int> getNextChapterOrder() async {
    try {
      final snapshot = await _firestore
          .collection(_chaptersCollection)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0;
      return ((snapshot.docs.first.data()['order'] as num?)?.toInt() ?? 0) + 1;
    } catch (e) {
      debugPrint('LessonService.getNextChapterOrder error: $e');
      return 0;
    }
  }

  void _adjustChapterLessonCount(WriteBatch batch, String chapterId,
      [int delta = 1]) {
    batch.set(
      _firestore.collection(_chaptersCollection).doc(chapterId),
      {'lessonCount': FieldValue.increment(delta)},
      SetOptions(merge: true),
    );
  }
}
