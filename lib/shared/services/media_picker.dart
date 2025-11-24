import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vcroad_v2/shared/utils/dialog/media_validation_dialog.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:vcroad_v2/shared/services/image.dart';

class MediaPickerService {
  MediaPickerService._();
  static final ImagePicker _picker = ImagePicker();

  /// Validates media for safe content using Vision API
  /// Returns null if valid, error message if invalid
  static Future<String?> _validateMediaContent(Uint8List bytes) async {
    try {
      final result = await ImageService.validateReportMedia(bytes);

      if (result['valid'] == true) {
        return null; // Valid
      }

      return result['reason'] ??
          'Media contains inappropriate content. Please choose different media.';
    } catch (e) {
      if (kDebugMode) print('Media validation error: $e');
      // Don't block submission on validation errors (network issues, etc)
      return null;
    }
  }

  /// WEB ONLY: Opens gallery to select an image. Returns Map with bytes and name.
  /// Validates content before returning.
  static Future<Map<String, dynamic>?> pickImageFromGalleryWeb(
    BuildContext context,
  ) async {
    if (!kIsWeb) return null;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 4000,
        maxHeight: 4000,
      );

      if (file == null) return null;

      final bytes = await file.readAsBytes();

      // Validate content
      final validationError = await _validateMediaContent(bytes);
      if (validationError != null) {
        if (context.mounted) {
          await showMediaValidationDialog(
            context,
            message: validationError,
            // use your police image asset if available:
            // imageWidget: Image.asset('assets/images/police_warning.png'),
            primaryLabel: 'Replace',
            onPrimary: () {
              // reopen gallery picker
              pickImageFromGalleryWeb(context);
            },
          );
        }
        return null;
      }

      return {'bytes': bytes, 'name': file.name};
    } catch (e) {
      if (kDebugMode) print('pickImageFromGalleryWeb error: $e');
      return null;
    }
  }

  /// MOBILE ONLY: Opens device camera to take a photo. Returns local file path.
  /// Validates content before returning.
  static Future<String?> pickImageFromCamera(BuildContext context) async {
    if (kIsWeb) return null;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 4000,
        maxHeight: 4000,
      );

      if (file == null) return null;

      // Validate content
      final bytes = await file.readAsBytes();
      final validationError = await _validateMediaContent(bytes);
      if (validationError != null) {
        if (context.mounted) {
          await showMediaValidationDialog(
            context,
            message: validationError,
            imageWidget: Image.asset('assets/images/police_warning.png'),
            primaryLabel: 'Retake',
            onPrimary: () {
              // reopen camera picker
              pickImageFromCamera(context);
            },
          );
        }
        return null;
      }

      return file.path;
    } catch (e) {
      if (kDebugMode) print('pickImageFromCamera error: $e');
      return null;
    }
  }

  /// MOBILE ONLY: Opens device camera to record a video. Validates duration (10-15s).
  /// Validates video thumbnail for safe content.
  /// Returns local file path or null.
  static Future<String?> pickVideoFromCamera(
    BuildContext context, {
    Duration minDuration = const Duration(seconds: 10),
    Duration maxDuration = const Duration(seconds: 15),
  }) async {
    if (kIsWeb) return null;

    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
      );
      if (file == null) return null;

      // Validate duration using video_player
      final controller = VideoPlayerController.file(File(file.path));
      try {
        await controller.initialize();
        final duration = controller.value.duration;
        await controller.dispose();

        if (duration < minDuration) {
          if (context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Video too short'),
                content: Text(
                  'Please record a video of at least ${minDuration.inSeconds} seconds.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return null;
        }

        if (duration >= maxDuration + const Duration(milliseconds: 500)) {
          // Accept up to 15.5s to allow for encoding drift
          if (context.mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Video too long'),
                content: Text(
                  'Please record a video of at most ${maxDuration.inSeconds} seconds.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return null;
        }

        // Extract multiple frames (start, middle, end) and validate sequentially.
        // This avoids uploading the whole video and is resilient if one frame is invalid.
        final msDuration = duration.inMilliseconds.clamp(0, 600000);
        final startMs = 100; // slightly after 0 to avoid blank frames
        final midMs = (msDuration ~/ 2).clamp(0, msDuration);
        final endMs = (msDuration - 200).clamp(0, msDuration);

        final frames = await _extractVideoFrames(
          file.path,
          timesMs: [startMs, midMs, endMs],
        );
        String? lastError;
        bool anyValid = false;
        for (final f in frames) {
          final err = await _validateMediaContent(f);
          if (err == null) {
            anyValid = true;
            break;
          }
          lastError = err;
        }

        if (!anyValid) {
          if (context.mounted) {
            await showMediaValidationDialog(
              context,
              message:
                  lastError ??
                  'Media contains inappropriate content. Please choose different media.',
              imageWidget: Image.asset('assets/images/police_warning.png'),
              primaryLabel: 'Retake',
              onPrimary: () {
                // reopen video recorder
                pickVideoFromCamera(context);
              },
            );
          }
          return null;
        }
      } catch (e) {
        if (kDebugMode) print('Video duration check failed: $e');
        try {
          await controller.dispose();
        } catch (_) {}
      }
      return file.path;
    } catch (e) {
      if (kDebugMode) print('pickVideoFromCamera error: $e');
      return null;
    }
  }

  /// Extract specific frames (as JPEG bytes) using video_thumbnail.
  /// timesMs list specifies frame timestamps in milliseconds.
  static Future<List<Uint8List>> _extractVideoFrames(
    String videoPath, {
    required List<int> timesMs,
    int maxWidth = 800,
    int quality = 80,
  }) async {
    final frames = <Uint8List>[];
    for (final t in timesMs) {
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: t < 0 ? 0 : t,
          maxWidth: maxWidth,
          quality: quality,
        );
        if (bytes != null && bytes.isNotEmpty) frames.add(bytes);
      } catch (e) {
        if (kDebugMode) print('frame extraction failed for $t ms: $e');
      }
      // small short-circuit: if we already have 3 frames, stop
      if (frames.length >= 3) break;
    }
    return frames;
  }
}
