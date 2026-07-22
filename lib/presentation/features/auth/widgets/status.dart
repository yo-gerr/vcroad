import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class VerificationStatus extends StatelessWidget {
  final String email;
  final String status; // 'pending' | 'verified' | 'expired'
  final VoidCallback onRefresh;
  final VoidCallback onResendEmail;
  final bool isRefreshing;

  const VerificationStatus({
    super.key,
    required this.email,
    required this.status,
    required this.onRefresh,
    required this.onResendEmail,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    Widget statusContent;
    Color iconColor;
    IconData iconData;
    String title;
    String message;

    switch (status) {
      case 'verified':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        title = 'Email verified!';
        message =
            'Your email has been successfully verified. You can now set your password.';
        break;
      case 'expired':
        iconData = Icons.error_outline;
        iconColor = Colors.red;
        title = 'Link expired';
        message =
            'Your verification link has expired. Please request a new one.';
        break;
      default: // pending
        iconData = Icons.mark_email_unread;
        iconColor = Colors.orange;
        title = 'Check your email';
        message =
            'We\'ve sent a verification link to $email. Click the link to verify your account.';
    }

    statusContent = Column(
      children: [
        Icon(iconData, size: responsive.scale(72), color: iconColor),
        SizedBox(height: responsive.scale(16)),
        Text(
          title,
          style: TextStyle(
            fontSize: responsive.scaleFont(20),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: responsive.scale(8)),
        Text(
          message,
          textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.scaleFont(14),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ),
      ],
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.horizontalPadding,
        vertical: responsive.verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statusContent,
          SizedBox(height: responsive.scale(24)),
          if (status != 'verified') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isRefreshing ? null : onRefresh,
                    icon: isRefreshing
                        ? SizedBox(
                            width: responsive.scale(20),
                            height: responsive.scale(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          )
                        : Icon(Icons.refresh, size: responsive.scale(20)),
                    label: Text(
                      'Refresh',
                      style: TextStyle(fontSize: responsive.scaleFont(14)),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(responsive.scale(48)),
                    ),
                  ),
                ),
                SizedBox(width: responsive.scale(12)),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRefreshing ? null : onResendEmail,
                    icon: Icon(Icons.email, size: responsive.scale(20)),
                    label: Text(
                      'Resend',
                      style: TextStyle(fontSize: responsive.scaleFont(14)),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.fromHeight(responsive.scale(48)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.scale(16)),
            Text(
              'The page will automatically update when your email is verified.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.scaleFont(12),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
