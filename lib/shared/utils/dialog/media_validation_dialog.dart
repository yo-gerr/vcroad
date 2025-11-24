import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

/// Reusable dialog for media (image/video) validation failures.
/// - `image` can be any widget (Image.asset/network/Icon) to show an illustration.
/// - `primaryLabel` is the main action (e.g. "Retake" / "Replace").
/// - `onPrimary` / `onDismiss` callbacks close the dialog and perform actions.
class MediaValidationDialog extends StatelessWidget {
  final String title;
  final String message;
  final Widget? image;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onDismiss;

  const MediaValidationDialog({
    super.key,
    this.title = 'Invalid Content',
    required this.message,
    this.image,
    this.primaryLabel = 'Retake',
    this.onPrimary,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: responsive.horizontalPadding,
        vertical: responsive.verticalPadding,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responsive.maxFormWidth),
        child: Padding(
          padding: EdgeInsets.all(responsive.scale(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: responsive.scale(110),
                child: Center(
                  child:
                      image ??
                      Image.asset(
                        'assets/images/wrong.webp',
                        fit: BoxFit.contain,
                        semanticLabel: 'Validation failed',
                      ),
                ),
              ),
              SizedBox(height: responsive.scale(18)),
              Text(
                title,
                style: TextStyle(
                  fontSize: responsive.scaleFont(20),
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.scale(10)),
              Text(
                message,
                style: TextStyle(
                  fontSize: responsive.scaleFont(15),
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.scale(18)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onPrimary != null)
                    ElevatedButton.icon(
                      icon: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        primaryLabel,
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          responsive.scale(130),
                          responsive.scale(44),
                        ),
                        backgroundColor: const Color(0xFF001278),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onPrimary?.call();
                      },
                    ),
                  if (onPrimary != null) SizedBox(width: responsive.scale(12)),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience helper to show the media validation dialog.
/// - `imageWidget` optional custom image (e.g. a provided police icon).
Future<void> showMediaValidationDialog(
  BuildContext context, {
  required String message,
  Widget? imageWidget,
  String primaryLabel = 'Retake',
  VoidCallback? onPrimary,
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => MediaValidationDialog(
      message: message,
      image: imageWidget,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      onDismiss: onDismiss,
    ),
  );
}
