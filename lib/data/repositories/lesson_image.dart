import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/data/repositories/storage.dart';

class LessonImageService {
  LessonImageService._();
  static final LessonImageService instance = LessonImageService._();

  final SupabaseStorageService _storage = SupabaseStorageService.instance;

  Future<QuizQuestion> uploadQuestionImages({
    required QuizQuestion question,
    required String lessonId,
  }) async {
    ImageRef? questionImage = question.questionImage;
    List<ImageRef?>? optionImages = question.optionImages;
    List<MatchingPair>? matchingPairs = question.matchingPairs;

    if (questionImage?.hasLocal ?? false) {
      final remoteUrl = await _uploadImage(
        questionImage!,
        'lessons/$lessonId/questions/${question.id}/question',
      );
      if (remoteUrl != null) {
        questionImage = ImageRef(remoteUrl: remoteUrl);
      }
    }

    if (optionImages != null && question.type == QuestionType.multipleChoice) {
      final updated = <ImageRef?>[];
      for (int i = 0; i < optionImages.length; i++) {
        final opt = optionImages[i];
        if (opt?.hasLocal ?? false) {
          final url = await _uploadImage(
            opt!,
            'lessons/$lessonId/questions/${question.id}/option_$i',
          );
          updated.add(url != null ? ImageRef(remoteUrl: url) : opt);
        } else {
          updated.add(opt);
        }
      }
      optionImages = updated;
    }

    if (matchingPairs != null && question.type == QuestionType.matchingType) {
      final updated = <MatchingPair>[];
      for (int i = 0; i < matchingPairs.length; i++) {
        final pair = matchingPairs[i];
        if (pair.image.hasLocal) {
          final url = await _uploadImage(
            pair.image,
            'lessons/$lessonId/questions/${question.id}/pair_$i',
          );
          updated.add(
            pair.copyWith(
              image: url != null ? ImageRef(remoteUrl: url) : pair.image,
            ),
          );
        } else {
          updated.add(pair);
        }
      }
      matchingPairs = updated;
    }

    return question.copyWith(
      questionImage: questionImage,
      optionImages: optionImages,
      matchingPairs: matchingPairs,
    );
  }

  Future<String?> _uploadImage(ImageRef imageRef, String storagePath) async {
    try {
      File? maybeFile;
      Uint8List? bytes;

      if (imageRef.xFile != null) {
        try {
          bytes = await imageRef.xFile!.readAsBytes();
        } catch (_) {}
      }

      if (imageRef.localPath != null && imageRef.localPath!.isNotEmpty) {
        try {
          final candidate = File(imageRef.localPath!);
          if (await candidate.exists()) {
            maybeFile = candidate;
          }
        } catch (_) {}
      }

      if (maybeFile == null && bytes == null && imageRef.xFile != null) {
        try {
          bytes = await imageRef.xFile!.readAsBytes();
        } catch (_) {}
      }

      if (maybeFile == null && bytes == null) {
        debugPrint('LessonImageService: No local file or bytes for upload');
        return null;
      }

      String extension;
      if (maybeFile != null) {
        extension = p.extension(maybeFile.path).toLowerCase();
      } else if (imageRef.xFile != null && imageRef.xFile!.name.isNotEmpty) {
        extension = p.extension(imageRef.xFile!.name).toLowerCase();
        if (extension.isEmpty) extension = '.jpg';
      } else {
        extension = '.jpg';
      }

      final uniqueId = const Uuid().v4();
      final isOption = storagePath.contains('/option_');
      final minWidth = isOption ? 400 : 1200;
      final quality = isOption ? 70 : 85;
      final fullPath = '${storagePath}_$uniqueId$extension';

      if (maybeFile != null) {
        File uploadFile = maybeFile;
        File? compressedFile;
        try {
          final tempDir = Directory.systemTemp;
          final compressedPath = p.join(
            tempDir.path,
            '${p.basenameWithoutExtension(uploadFile.path)}_cmp$extension',
          );
          compressedFile =
              (await FlutterImageCompress.compressAndGetFile(
                uploadFile.path,
                compressedPath,
                quality: quality,
                minWidth: minWidth,
              )) as File?;
          if (compressedFile != null && await compressedFile.exists()) {
            uploadFile = compressedFile;
          }
        } catch (e) {
          debugPrint('LessonImageService: compression failed: $e');
        }
        final url = await _storage.uploadFile(path: fullPath, file: uploadFile);
        try {
          if (compressedFile != null && await compressedFile.exists()) {
            await compressedFile.delete();
          }
        } catch (_) {}
        return url;
      }

      if (bytes != null && bytes.isNotEmpty) {
        return await _storage.uploadBytes(
          path: fullPath,
          bytes: bytes,
          contentType: _mimeType(extension),
        );
      }

      return null;
    } catch (e) {
      debugPrint('LessonImageService._uploadImage error: $e');
      return null;
    }
  }

  /// Maps a file extension (with or without the leading dot) to a valid MIME
  /// type for the storage upload bytes branch (used on web).
  static String _mimeType(String extension) {
    switch (extension.replaceFirst('.', '').toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> deleteLessonImages(String lessonId) async {
    try {
      await _storage.deleteFolder('lessons/$lessonId');
    } catch (e) {
      debugPrint('LessonImageService.deleteLessonImages error: $e');
    }
  }
}
