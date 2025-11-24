import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class ImageValidationDialog extends StatelessWidget {
  final String slotLabel; // e.g. "Front of ID" or "Selfie with ID"
  final String message;
  final VoidCallback? onRetake;
  final VoidCallback? onDismiss;

  const ImageValidationDialog({
    super.key,
    required this.slotLabel,
    required this.message,
    this.onRetake,
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
          padding: EdgeInsets.all(responsive.scale(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Larger failed image, removed "Issue with" label
              SizedBox(
                height: responsive.scale(120),
                child: Image.asset(
                  'assets/images/failed.webp',
                  fit: BoxFit.contain,
                  semanticLabel: 'Validation failed',
                ),
              ),
              SizedBox(height: responsive.scale(20)),
              Text(
                'Image Validation Failed',
                style: TextStyle(
                  fontSize: responsive.scaleFont(20),
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.scale(12)),
              Text(
                message,
                style: TextStyle(
                  fontSize: responsive.scaleFont(15),
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: responsive.scale(24)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onRetake != null)
                    ElevatedButton.icon(
                      icon: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Retake Photo',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          responsive.scale(120),
                          responsive.scale(44),
                        ),
                        backgroundColor: const Color(0xFF001278),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetake?.call();
                      },
                    ),
                  SizedBox(width: responsive.scale(12)),
                  TextButton(
                    child: Text('Dismiss'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
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
