import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

/// Show fullscreen image preview with dark background, pinch/zoom, close button
Future<void> showImagePreviewDialog(BuildContext context, dynamic image) {
  Widget imageWidget;
  if (image is Uint8List) {
    imageWidget = Image.memory(image, fit: BoxFit.contain);
  } else if (image is String) {
    imageWidget = Image.network(
      image,
      fit: BoxFit.contain,
    ); // Use network for web
  } else {
    imageWidget = const SizedBox.shrink();
  }

  final heroTag = 'id_capture_preview_${identityHashCode(image)}';

  return showGeneralDialog(
    context: context,
    barrierLabel: 'Image preview',
    barrierDismissible: true,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, anim1, anim2) {
      final responsive = context.responsive;
      return Dismissible(
        key: const Key('preview'),
        direction: DismissDirection.vertical,
        onDismissed: (_) => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Hero(tag: heroTag, child: imageWidget),
                  ),
                ),
                Positioned(
                  top: responsive.scale(16),
                  right: responsive.scale(16),
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: responsive.scale(28),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ),
                ),
                Positioned(
                  bottom: responsive.scale(16),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Builder(
                      builder: (ctx) {
                        // increase base font on mobile for legibility, keep slightly smaller on desktop
                        final baseFont = responsive.isMobile ? 16.0 : 14.0;
                        return Text(
                          'Pinch to zoom • Swipe down to close',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: responsive.scaleFont(baseFont),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
