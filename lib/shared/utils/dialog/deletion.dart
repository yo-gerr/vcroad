import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/format/date_time.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class PendingDeletionDialog extends StatelessWidget {
  final DateTime scheduledForDeletionAt;
  final VoidCallback onCancelDeletion;
  final VoidCallback onDismiss;

  const PendingDeletionDialog({
    super.key,
    required this.scheduledForDeletionAt,
    required this.onCancelDeletion,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final maxWidth = info.isMobile ? double.infinity : 400.0;

    // PopScope API varies across SDK versions. Keep WillPopScope for compatibility
    // and suppress the deprecation warning until you migrate to PopScope.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
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
                SizedBox(
                  height: info.scale(96),
                  width: info.scale(96),
                  child: Image.asset(
                    'assets/images/wrong.webp',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                SizedBox(height: info.scale(16)),
                Text(
                  'Account Deletion Scheduled',
                  style: TextStyle(
                    fontSize: info.scaleFont(18),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: info.scale(12)),
                Text(
                  'Your account is scheduled to be permanently deleted on:',
                  style: TextStyle(fontSize: info.scaleFont(14)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: info.scale(8)),
                Text(
                  DateFormatUtils.formatFriendly(scheduledForDeletionAt),
                  style: TextStyle(
                    fontSize: info.scaleFont(16),
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: info.scale(16)),
                Text(
                  'You can cancel the deletion before the scheduled date.',
                  style: TextStyle(
                    fontSize: info.scaleFont(13),
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: info.scale(24)),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onCancelDeletion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cancel Deletion'),
                      ),
                    ),
                    SizedBox(height: info.scale(12)),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onDismiss,
                        child: const Text('Dismiss'),
                      ),
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
}
