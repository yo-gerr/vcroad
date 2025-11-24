import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

Future<void> showSomethingWentWrongDialog({
  required BuildContext context,
  required String message,
  required VoidCallback onRetry,
}) async {
  final responsive = context.responsive;
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
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
              SizedBox(
                height: responsive.scale(120),
                child: Image.asset(
                  'assets/images/wrong.webp', // Place your image here
                  fit: BoxFit.contain,
                  semanticLabel: 'Something went wrong',
                ),
              ),
              SizedBox(height: responsive.scale(20)),
              Text(
                'Something Went Wrong',
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
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    label: Text('Retry', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001278),
                      foregroundColor: Colors.white,
                      minimumSize: Size(
                        responsive.scale(120),
                        responsive.scale(44),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRetry();
                    },
                  ),
                  SizedBox(width: responsive.scale(12)),
                  TextButton(
                    child: Text('Dismiss'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
