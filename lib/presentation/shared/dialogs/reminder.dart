import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_text_styles.dart';

/// Show a simple reminder dialog on each app open.
/// This dialog contains a single image asset and an OK button (non-dismissible).
Future<void> showReminderOnLaunch(BuildContext context) async {
  final info = context.responsive;

  // Portrait dialog sizing: width lower than height. Keep responsive caps.
  final double maxDialogWidth = info.isDesktop
      ? info.screenWidth * 0.42
      : info.screenWidth * 0.92;
  final double preferredWidth = maxDialogWidth.clamp(
    320.0,
    info.screenWidth * 0.92,
  );
  // portrait aspect ratio ~ 9:16 (height larger)
  final double preferredHeight = (preferredWidth * 16.0 / 9.0).clamp(
    480.0,
    info.screenHeight * 0.92,
  );

  final dialogWidth = math.min(preferredWidth, info.screenWidth * 0.92);
  final dialogHeight = math.min(preferredHeight, info.screenHeight * 0.92);

  final imageMaxWidth = dialogWidth * 0.94;
  final imageMaxHeight = dialogHeight * 0.82;

  // Precache a resized version of the image to keep the dialog snappy.
  final cacheW = context.cacheWidthForImage(imageMaxWidth);
  final asset = ResizeImage(
    const AssetImage('assets/images/reminder.webp'),
    width: cacheW,
  );
  await precacheImage(asset, context);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false, // enforce OK button to dismiss
    builder: (_) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: (info.screenWidth - dialogWidth) / 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(info.scale(10)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: imageMaxWidth,
                        maxHeight: imageMaxHeight,
                      ),
                      child: Image(
                        image: asset,
                        fit: BoxFit.contain,
                        semanticLabel: 'Reminder',
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: info.scale(16),
                  vertical: info.scale(12),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: info.scale(12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: AppTextStyles.button,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
