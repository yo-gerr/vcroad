import 'package:flutter/material.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/data/repositories/image.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/format/text.dart';
import 'package:vcroad/presentation/features/profile/widgets/badges.dart';

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
      avatarWidget = FutureBuilder<String?>(
        future: ImageService.getDownloadUrlCached(selfiePath),
        builder: (context, snap) {
          return ImageService.buildCachedAvatar(
            imageUrl: snap.data,
            radius: avatarSize / 2,
            placeholderAsset: brandAsset,
            cacheWidth: avatarSize.toInt(),
          );
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: Semantics(
              label: 'Profile photo',
              image: true,
              child: avatarWidget,
            ),
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
            RoleBadge(role: user.role),
            if (user.isVerified)
              const VerificationBadge()
            else
              const UnverifiedBadge(),
          ],
        ),
      ],
    );
  }
}
