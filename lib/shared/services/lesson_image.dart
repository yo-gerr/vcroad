import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad_v2/shared/models/lesson.dart';
import 'package:vcroad_v2/shared/models/question.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class LessonImageService {
  LessonImageService._();
  static final LessonImageService instance = LessonImageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Collect all remote urls referenced by a lesson (questions, options, matching pairs, thumbnail)
  Set<String> collectRemoteUrlsFromLesson(QuizMaterial lesson) {
    final urls = <String>{};

    if (lesson.thumbnailUrl != null && lesson.thumbnailUrl!.isNotEmpty) {
      urls.add(lesson.thumbnailUrl!);
    }

    for (final q in lesson.questions) {
      final qi = q.questionImage;
      if (qi != null && qi.remoteUrl != null && qi.remoteUrl!.isNotEmpty) {
        urls.add(qi.remoteUrl!);
      }

      if (q.optionImages != null) {
        for (final opt in q.optionImages!) {
          if (opt != null &&
              opt.remoteUrl != null &&
              opt.remoteUrl!.isNotEmpty) {
            urls.add(opt.remoteUrl!);
          }
        }
      }

      if (q.matchingPairs != null) {
        for (final p in q.matchingPairs!) {
          if (p.image.remoteUrl != null && p.image.remoteUrl!.isNotEmpty) {
            urls.add(p.image.remoteUrl!);
          }
        }
      }
    }

    return urls;
  }

  /// Delete multiple remote files by their download URLs. Ignores failures per item.
  Future<void> deleteRemoteFilesByUrls(Iterable<String> urls) async {
    final unique = urls.where((u) => u.isNotEmpty).toSet();
    if (unique.isEmpty) return;

    // Bound concurrent deletes
    final sem = Pool(4);
    final deleteFutures = unique.map((url) {
      return sem.withResource(() async {
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (e) {
          debugPrint('LessonImageService: failed to delete $url: $e');
        }
      });
    }).toList();

    await Future.wait(deleteFutures);
  }

  /// Upload all images in a lesson and return updated lesson with remote URLs
  Future<QuizMaterial> uploadLessonImages(QuizMaterial lesson) async {
    // Limit concurrent uploads to avoid saturating network (and to play nice with
    // browser limits). Tune `concurrency` as needed.
    const int concurrency = 4;

    final questions = lesson.questions.toList();
    final updated = List<QuizQuestion?>.filled(questions.length, null);
    final sem = Pool(concurrency);
    final futures = <Future>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      futures.add(
        sem.withResource(() async {
          try {
            final up = await _uploadQuestionImages(q, lesson.id);
            updated[i] = up;
          } catch (e) {
            debugPrint(
              'LessonImageService: failed uploading images for question ${q.id}: $e',
            );
            updated[i] = q; // fallback to original so we don't lose question
          }
        }),
      );
    }

    await Future.wait(futures);

    // Preserve original per-index question on upload failure
    final newQuestions = List<QuizQuestion>.generate(
      questions.length,
      (i) => updated[i] ?? questions[i],
    );

    return lesson.copyWith(questions: newQuestions);
  }

  /// Upload images for a single question
  Future<QuizQuestion> _uploadQuestionImages(
    QuizQuestion question,
    String lessonId,
  ) async {
    ImageRef? questionImage = question.questionImage;
    List<ImageRef?>? optionImages = question.optionImages;
    List<MatchingPair>? matchingPairs = question.matchingPairs;

    // Upload question image if local
    if (questionImage?.hasLocal ?? false) {
      final remoteUrl = await _uploadImage(
        questionImage!,
        'lessons/$lessonId/questions/${question.id}/question_image',
      );
      if (remoteUrl != null) {
        questionImage = ImageRef(remoteUrl: remoteUrl);
      }
    }

    // Upload option images for multiple choice
    if (optionImages != null && question.type == QuestionType.multipleChoice) {
      final updatedOptionImages = <ImageRef?>[];
      for (int i = 0; i < optionImages.length; i++) {
        final optionImage = optionImages[i];
        if (optionImage?.hasLocal ?? false) {
          final remoteUrl = await _uploadImage(
            optionImage!,
            'lessons/$lessonId/questions/${question.id}/option_$i',
          );
          updatedOptionImages.add(
            remoteUrl != null ? ImageRef(remoteUrl: remoteUrl) : optionImage,
          );
        } else {
          updatedOptionImages.add(optionImage);
        }
      }
      optionImages = updatedOptionImages;
    }

    // Upload matching pair images
    if (matchingPairs != null && question.type == QuestionType.matchingType) {
      final updatedPairs = <MatchingPair>[];
      for (int i = 0; i < matchingPairs.length; i++) {
        final pair = matchingPairs[i];
        if (pair.image.hasLocal) {
          final remoteUrl = await _uploadImage(
            pair.image,
            'lessons/$lessonId/questions/${question.id}/pair_$i',
          );
          updatedPairs.add(
            pair.copyWith(
              image: remoteUrl != null
                  ? ImageRef(remoteUrl: remoteUrl)
                  : pair.image,
            ),
          );
        } else {
          updatedPairs.add(pair);
        }
      }
      matchingPairs = updatedPairs;
    }

    return question.copyWith(
      questionImage: questionImage,
      optionImages: optionImages,
      matchingPairs: matchingPairs,
    );
  }

  /// Upload a single image and return remote URL
  Future<String?> _uploadImage(ImageRef imageRef, String storagePath) async {
    try {
      File? maybeFile;
      Uint8List? bytes;

      // Prefer XFile bytes if present (works for web blob: URIs and mobile).
      if (imageRef.xFile != null) {
        try {
          bytes = await imageRef.xFile!.readAsBytes();
        } catch (e) {
          debugPrint('LessonImageService: failed to read xFile bytes: $e');
        }
      }

      if (imageRef.localPath != null && imageRef.localPath!.isNotEmpty) {
        try {
          final candidate = File(imageRef.localPath!);
          if (await candidate.exists()) {
            maybeFile = candidate;
          } else {
            // localPath can be a blob: URI (web). prefer xFile in that case.
            debugPrint(
              'LessonImageService: localPath does not point to a File, will prefer xFile if available',
            );
          }
        } catch (e) {
          debugPrint('LessonImageService: checking localPath failed: $e');
        }
      }

      // If we still don't have bytes but have an xFile we tried reading above.
      if (maybeFile == null && bytes == null && imageRef.xFile != null) {
        try {
          bytes = await imageRef.xFile!.readAsBytes();
        } catch (e) {
          debugPrint(
            'LessonImageService: second attempt readAsBytes failed: $e',
          );
        }
      }

      if (maybeFile == null && bytes == null) {
        debugPrint(
          'LessonImageService: No local file or xFile bytes available for upload (path: ${imageRef.localPath})',
        );
        return null;
      }

      // Decide extension for storage path
      String extension;
      if (maybeFile != null) {
        extension = path.extension(maybeFile.path).toLowerCase();
      } else if (imageRef.xFile != null && imageRef.xFile!.name.isNotEmpty) {
        extension = path.extension(imageRef.xFile!.name).toLowerCase();
        if (extension.isEmpty) extension = '.jpg';
      } else {
        extension = '.jpg';
      }

      // Use unique filename to avoid path collisions that lead to accidental deletion
      final uniqueId = const Uuid().v4();
      final fullPath = '${storagePath}_$uniqueId$extension';
      final ref = _storage.ref().child(fullPath);

      // If we have a real file, attempt compression/resizing first for bandwidth.
      if (maybeFile != null) {
        File uploadFile = maybeFile;
        File? compressedFile;

        try {
          final tempDir = Directory.systemTemp;
          final compressedPath = path.join(
            tempDir.path,
            '${path.basenameWithoutExtension(uploadFile.path)}_cmp$extension',
          );

          compressedFile =
              (await FlutterImageCompress.compressAndGetFile(
                    uploadFile.path,
                    compressedPath,
                    quality: 85,
                    minWidth: 1200,
                  ))
                  as File?;

          if (compressedFile != null && await compressedFile.exists()) {
            uploadFile = compressedFile;
          }
        } catch (e) {
          debugPrint('LessonImageService: compression failed: $e');
          // fallback to original file
          uploadFile = maybeFile;
        }

        final uploadTaskSnapshot = await ref.putFile(
          uploadFile,
          SettableMetadata(contentType: _getContentType(extension)),
        );

        // cleanup temp compressed file
        try {
          if (compressedFile != null && await compressedFile.exists()) {
            await compressedFile.delete();
          }
        } catch (_) {}
        final downloadUrl = await uploadTaskSnapshot.ref.getDownloadURL();
        return downloadUrl;
      }

      // Otherwise upload bytes (from XFile). This path is used for web or when
      // XFile is present but a usable local file isn't available.
      if (bytes != null && bytes.isNotEmpty) {
        final uploadTaskSnapshot = await ref.putData(
          bytes,
          SettableMetadata(contentType: _getContentType(extension)),
        );
        final downloadUrl = await uploadTaskSnapshot.ref.getDownloadURL();
        return downloadUrl;
      } else {
        debugPrint('LessonImageService: bytes are empty, cannot upload');
        return null;
      }
    } catch (e) {
      debugPrint('LessonImageService._uploadImage error: $e');
      return null;
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Delete all images associated with a lesson
  Future<void> deleteLessonImages(String lessonId) async {
    try {
      final ref = _storage.ref().child('lessons/$lessonId');
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }

      for (final prefix in listResult.prefixes) {
        await _deleteFolder(prefix);
      }
    } catch (e) {
      debugPrint('LessonImageService.deleteLessonImages error: $e');
    }
  }

  Future<void> _deleteFolder(Reference ref) async {
    try {
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        await item.delete();
      }

      for (final prefix in listResult.prefixes) {
        await _deleteFolder(prefix);
      }
    } catch (e) {
      debugPrint('LessonImageService._deleteFolder error: $e');
    }
  }
}

// small Pool helper using Futures to limit concurrency
class Pool {
  final int _max;
  int _current = 0;
  final Queue<_CompleterToken> _queue = Queue();
  Pool(this._max);

  Future<T> withResource<T>(Future<T> Function() fn) async {
    if (_current >= _max) {
      final token = _CompleterToken();
      _queue.add(token);
      await token.completer.future;
    }
    _current++;
    try {
      return await fn();
    } finally {
      _current--;
      if (_queue.isNotEmpty) {
        final next = _queue.removeFirst();
        next.completer.complete();
      }
    }
  }
}

class _CompleterToken {
  final Completer<void> completer = Completer<void>();
}
