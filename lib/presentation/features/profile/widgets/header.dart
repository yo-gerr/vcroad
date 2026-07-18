import 'package:flutter/material.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/data/repositories/image.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/format/text.dart';

class ProfileHeader extends StatelessWidget {
  final UserDetails user;
  const ProfileHeader({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avatarSize = context.scale(
      160,
      mobileFactor: 0.75,
      tabletFactor: 0.85,
    );
    final nameStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: context.scaleFont(22),
      fontWeight: FontWeight.w700,
      color: colorScheme.primary,
      letterSpacing: 0.6,
    );
    final emailStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: context.scaleFont(14),
      color: colorScheme.onSurfaceVariant,
    );

    final String? selfiePath = user.selfiePath;
    final String? cachedUrl = ImageService.peekCachedUrl(selfiePath);

    // For admin/sysadmin show branded asset instead of user selfie.
    final bool useBrandAvatar =
        user.role == UserRole.admin || user.role == UserRole.sysadmin;
    const String brandAsset = 'assets/images/vcroad.webp';

    Widget avatarWidget;
    if (useBrandAvatar) {
      avatarWidget = CircleAvatar(
        radius: avatarSize / 2,
        backgroundColor: colorScheme.surface,
        child: ClipOval(
          child: Image.asset(
            brandAsset,
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                size: avatarSize * 0.5,
                color: colorScheme.onSurfaceVariant,
              );
            },
          ),
        ),
      );
    } else {
      avatarWidget = ImageService.buildCachedAvatar(
        imageUrl: cachedUrl,
        radius: avatarSize / 2,
        placeholderAsset: brandAsset,
        cacheWidth: avatarSize.toInt(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: avatarWidget,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${user.firstName} ${user.lastName}'.trim().asTitleCase,
          style: nameStyle,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        Text(user.email, style: emailStyle, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _RoleBadge(role: user.role),
            if (user.isVerified)
              _VerificationBadge()
            else
              _UnverifiedBadge(),
          ],
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String label) = switch (role) {
      UserRole.user => (
        Colors.blue.shade50,
        Colors.blue.shade700,
        Icons.person_outline,
        'Road User',
      ),
      UserRole.admin => (
        Colors.orange.shade50,
        Colors.orange.shade800,
        Icons.admin_panel_settings_outlined,
        'Barangay Admin',
      ),
      UserRole.sysadmin => (
        Colors.purple.shade50,
        Colors.purple.shade700,
        Icons.security_outlined,
        'Super Admin',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnverifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          Text(
            'Unverified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
