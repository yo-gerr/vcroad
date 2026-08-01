import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/presentation/features/auth/screens/reset_password_screen.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/data/repositories/auth.dart';
import 'package:vcroad/data/repositories/image.dart';
import 'package:vcroad/presentation/shared/dialogs/confirmation.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/constants/config.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart'; // <-- Import SnackbarUtils
import 'package:vcroad/presentation/providers/theme.dart';
import 'package:vcroad/presentation/features/auth/widgets/faq.dart';
import 'package:vcroad/presentation/features/auth/widgets/support.dart';

class AccountSettings extends StatelessWidget {
  final UserDetails user;
  const AccountSettings({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sectionTitleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.primary,
      fontSize: context.scaleFont(14),
    );

    ListTile buildItem({
      required IconData icon,
      required String label,
      Color? iconColor,
      VoidCallback? onTap,
    }) {
      return ListTile(
        leading: Icon(icon, color: iconColor ?? colorScheme.primary),
        title: Text(
          label,
          style: TextStyle(
            fontSize: context.scaleFont(15),
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 12,
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 40, color: colorScheme.outlineVariant),
        buildItem(
          icon: Icons.info_outline,
          label: 'Profile Details',
          onTap: () => context.push('/profile-details'),
        ),
        const SizedBox(height: 8),
        // Help section (FAQ + Support) - available to all roles
        Text('Help', style: sectionTitleStyle),
        Divider(height: 12, color: colorScheme.outlineVariant),
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
        Text('Appearance', style: sectionTitleStyle),
        Divider(height: 12, color: colorScheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _ThemeSelector(),
        ),
        const SizedBox(height: 8),
        Text('Account Settings', style: sectionTitleStyle),
        Divider(height: 20, color: colorScheme.outlineVariant),
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
        Divider(height: 40, color: colorScheme.outlineVariant),
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
        const SizedBox(height: 32),
        Center(
          child: Text(
            '${AppConfig.appName} ${AppConfig.appVersion}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final themeMode = themeProvider.themeMode;
    final modeLabel = switch (themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.brightness_6, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              'Theme',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              modeLabel,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness), label: Text('System')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
          ],
          selected: {themeMode},
          onSelectionChanged: (Set<ThemeMode> selected) {
            final mode = selected.first;
            switch (mode) {
              case ThemeMode.light:
                themeProvider.setLight();
              case ThemeMode.dark:
                themeProvider.setDark();
              case ThemeMode.system:
                themeProvider.setSystem();
            }
          },
        ),
      ],
    );
  }
}
