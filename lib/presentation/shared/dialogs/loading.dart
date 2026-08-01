import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class LoadingDialog extends StatelessWidget {
  final String? message;
  final double? size;
  const LoadingDialog({super.key, this.message, this.size});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final cs = Theme.of(context).colorScheme;
    final logoSize = (size ?? info.logoSize * 0.6).clamp(64.0, 220.0);

    return Dialog(
      elevation: 0,
      backgroundColor: cs.surface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: info.isDesktop ? 120 : 32,
        vertical: info.isDesktop ? 80 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: info.scale(32),
          horizontal: info.scale(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: SizedBox(
                width: logoSize,
                height: logoSize,
                child: Lottie.asset(
                  'assets/lottie/traffic_light.json',
                  repeat: true,
                  animate: true,
                  fit: BoxFit.contain,
                  frameRate: FrameRate.max,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 18),
              Text(
                message!,
                style: TextStyle(
                  fontSize: info.scaleFont(16),
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
