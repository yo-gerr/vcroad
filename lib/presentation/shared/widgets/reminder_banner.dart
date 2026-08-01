import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class ReminderBanner extends StatelessWidget {
  final VoidCallback? onDismiss;

  const ReminderBanner({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s = context.scale;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: s(16), vertical: s(8)),
      padding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(s(12)),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: s(22), color: Theme.of(context).colorScheme.primary),
          SizedBox(width: s(12)),
          Expanded(
            child: Text(
              'Stay safe! Report road hazards and track their status in your community.',
              style: TextStyle(fontSize: s(13), color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          SizedBox(width: s(8)),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: s(18), color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
