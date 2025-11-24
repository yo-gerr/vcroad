import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:vcroad_v2/shared/models/report.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class MediaStep extends StatelessWidget {
  final MediaType? selectedMediaType;
  final dynamic
  mediaPath; // String (mobile file path) or Map {bytes, name} (web)
  final ValueChanged<MediaType> onPickMedia;
  final VoidCallback onRetake;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const MediaStep({
    super.key,
    required this.selectedMediaType,
    required this.mediaPath,
    required this.onPickMedia,
    required this.onRetake,
    required this.onBack,
    required this.onNext,
  });

  String _getFileName() {
    try {
      if (mediaPath is String) {
        return p.basename(mediaPath as String);
      } else if (mediaPath is Map && mediaPath.containsKey('name')) {
        return mediaPath['name'] as String;
      }
      return 'image';
    } catch (_) {
      return 'image';
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final maxPreviewHeight = MediaQuery.of(context).size.height * 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          kIsWeb ? 'Upload Photo' : 'Capture Media',
          style: TextStyle(
            fontSize: info.scaleFont(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          kIsWeb
              ? 'Select a photo from your device'
              : 'Take a photo or record a 10-15 second video\n'
                    'Content will be validated for appropriateness',
          style: TextStyle(
            fontSize: info.scaleFont(14),
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        if (mediaPath == null) ...[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (kIsWeb) ...[
                  // WEB: Only show image selection
                  Tooltip(
                    message:
                        'Select a photo (will be validated for safe content)',
                    child: ElevatedButton.icon(
                      onPressed: () => onPickMedia(MediaType.photo),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Select Photo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // MOBILE: Show camera options for photo and video
                  Tooltip(
                    message: 'Take a photo (will be validated)',
                    child: ElevatedButton.icon(
                      onPressed: () => onPickMedia(MediaType.photo),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Tooltip(
                    message: 'Record video (will be validated)',
                    child: ElevatedButton.icon(
                      onPressed: () => onPickMedia(MediaType.video),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Record Video'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          // Preview area
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxPreviewHeight,
                  maxWidth: 800,
                ),
                child: Semantics(
                  label: selectedMediaType == MediaType.photo
                      ? 'Photo preview'
                      : 'Video preview',
                  child: selectedMediaType == MediaType.photo
                      ? _buildPhotoPreview()
                      : _buildVideoPreview(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Metadata + retake control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getFileName(),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retake'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: 'Go back to previous step',
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Back'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: mediaPath == null
                    ? (kIsWeb
                          ? 'Select a photo to continue'
                          : 'Capture media to continue')
                    : 'Proceed to next step',
                child: ElevatedButton(
                  onPressed: mediaPath == null ? null : onNext,
                  child: const Text('Next'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    if (kIsWeb) {
      // Web: display from bytes
      if (mediaPath is Map && mediaPath.containsKey('bytes')) {
        final bytes = mediaPath['bytes'] as Uint8List;
        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(Icons.broken_image, size: 72, color: Colors.grey),
            ),
          ),
        );
      }
      return const Center(
        child: Icon(Icons.error_outline, size: 72, color: Colors.red),
      );
    } else {
      // Mobile: display from file path
      if (mediaPath is String) {
        return InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.file(
            File(mediaPath as String),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(Icons.broken_image, size: 72, color: Colors.grey),
            ),
          ),
        );
      }
      return const Center(
        child: Icon(Icons.error_outline, size: 72, color: Colors.red),
      );
    }
  }

  Widget _buildVideoPreview() {
    // Video preview placeholder (only available on mobile)
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.videocam, size: 96, color: Colors.black38),
        ),
        const Tooltip(
          message: 'Video recorded (10-15 seconds)',
          child: CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white70,
            child: Icon(Icons.check_circle, size: 40, color: Colors.green),
          ),
        ),
      ],
    );
  }
}
