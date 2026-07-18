import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final maxWidth = info.isMobile ? double.infinity : 360.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: info.isMobile
            ? 16
            : (MediaQuery.of(context).size.width - maxWidth) / 2,
        vertical: info.scale(24),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.all(info.scale(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: info.scaleFont(18),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: info.scale(16)),
              Text(
                message,
                style: TextStyle(fontSize: info.scaleFont(14)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: info.scale(24)),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(cancelText),
                    ),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(confirmText),
                    ),
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
