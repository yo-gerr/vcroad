import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/format/date_time.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class SessionConflictDialog extends StatelessWidget {
  final String deviceInfo;
  final DateTime? startedAt;
  final VoidCallback onForceLogout;
  final VoidCallback onCancel;

  const SessionConflictDialog({
    super.key,
    required this.deviceInfo,
    this.startedAt,
    required this.onForceLogout,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final imageSize = info.isMobile ? 96.0 : 120.0;
    final maxWidth = info.isMobile ? double.infinity : 400.0;

    // PopScope API varies by SDK version. Keep WillPopScope for compatibility
    // and suppress the deprecation lint until you migrate to PopScope.
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
                  height: imageSize,
                  width: imageSize,
                  child: Image.asset(
                    'assets/images/wrong.webp',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                SizedBox(height: info.scale(16)),
                Text(
                  'Another Device Logged In',
                  style: TextStyle(
                    fontSize: info.scaleFont(18),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: info.scale(12)),
                Text(
                  'Your account is currently active on:\n$deviceInfo',
                  style: TextStyle(fontSize: info.scaleFont(14)),
                  textAlign: TextAlign.center,
                ),
                if (startedAt != null) ...[
                  SizedBox(height: info.scale(8)),
                  Text(
                    'Since: ${DateFormatUtils.formatFriendly(startedAt!)}',
                    style: TextStyle(
                      fontSize: info.scaleFont(12),
                      color: Colors.grey,
                    ),
                  ),
                ],
                SizedBox(height: info.scale(24)),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: info.scale(12)),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onForceLogout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Force Logout'),
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
