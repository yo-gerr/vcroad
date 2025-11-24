import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/features/reset.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/services/auth.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/utils/dialog/confirmation.dart';
import 'package:vcroad_v2/shared/utils/dialog/loading.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/profile/details.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart'; // <-- Import SnackbarUtils
import 'package:vcroad_v2/shared/widgets/login/faq.dart';
import 'package:vcroad_v2/shared/widgets/login/support.dart';

class AccountSettings extends StatelessWidget {
  final UserDetails user;
  const AccountSettings({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    final sectionTitleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF052676),
      fontSize: context.scaleFont(14),
    );

    ListTile buildItem({
      required IconData icon,
      required String label,
      Color? iconColor,
      VoidCallback? onTap,
    }) {
      return ListTile(
        leading: Icon(icon, color: iconColor ?? const Color(0xFF052676)),
        title: Text(
          label,
          style: TextStyle(
            fontSize: context.scaleFont(15),
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 12,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 40, color: Colors.grey.shade300),
        buildItem(
          icon: Icons.info_outline,
          label: 'Profile Details',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileDetails()));
          },
        ),
        const SizedBox(height: 8),
        // Help section (FAQ + Support) - available to all roles
        Text('Help', style: sectionTitleStyle),
        Divider(height: 12, color: Colors.grey.shade200),
        buildItem(
          icon: Icons.question_mark,
          label: 'FAQ',
          onTap: () => Navigator.of(context).push(FAQ.route()),
        ),
        buildItem(
          icon: Icons.alternate_email,
          label: 'Support',
          onTap: () => Navigator.of(context).push(SupportScreen.route()),
        ),
        const SizedBox(height: 8),
        Text('Account Settings', style: sectionTitleStyle),
        Divider(height: 20, color: Colors.grey.shade300),
        buildItem(
          icon: Icons.lock_outline,
          label: 'Change Password',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ResetPassword()));
          },
        ),
        buildItem(
          icon: Icons.delete_outline,
          label: 'Delete Account',
          iconColor: Colors.redAccent,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => const ConfirmationDialog(
                title: 'Delete Account',
                message:
                    'Are you sure you want to delete your account? This action will schedule your account for permanent deletion in 30 days. You can cancel before the deletion date.',
                confirmText: 'Delete',
                cancelText: 'Cancel',
              ),
            );
            if (confirmed != true) return;
            if (!context.mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const LoadingDialog(
                message: 'Scheduling account deletion...',
              ),
            );
            try {
              await AuthService.instance.requestAccountDeletion(user.userId);

              // Guard against using BuildContext after async gaps
              if (!context.mounted) return;

              Navigator.of(context).pop();
              SnackbarUtils.showSuccess(
                context,
                'Account scheduled for deletion in 30 days.',
              );

              // Sign out after scheduling deletion
              await AuthService.instance.signOut();

              // Re-check mounted before using context again after the async call
              if (!context.mounted) return;

              context.read<UserProvider>().clearUser();
              GoRouter.of(context).go('/login');
            } catch (e) {
              if (context.mounted) {
                Navigator.of(context).pop();
                SnackbarUtils.showError(
                  context,
                  'Failed to schedule deletion: $e',
                );
              }
            }
          },
        ),
        Divider(height: 40, color: Colors.grey.shade300),
        buildItem(
          icon: Icons.logout,
          label: 'Log Out',
          iconColor: Colors.red,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => const ConfirmationDialog(
                title: 'Log Out',
                message: 'Are you sure you want to log out?',
                confirmText: 'Log Out',
                cancelText: 'Cancel',
              ),
            );
            if (confirmed != true) return;
            if (!context.mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const LoadingDialog(message: 'Logging out...'),
            );
            try {
              await AuthService.instance.signOut();
              // Clear image cache for optimal performance
              await ImageService.clearImageCache();
              if (!context.mounted) return;
              context.read<UserProvider>().clearUser();
              Navigator.of(context).pop(); // Dismiss loading dialog
              GoRouter.of(context).go('/login');
              SnackbarUtils.showSuccess(context, 'Logged out successfully.');
            } catch (e) {
              if (context.mounted) {
                Navigator.of(context).pop();
                SnackbarUtils.showError(context, 'Log out failed: $e');
              }
            }
          },
        ),
      ],
    );
  }
}
