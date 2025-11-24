import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/format/text.dart';

class ProfileHeader extends StatelessWidget {
  final UserDetails user;
  const ProfileHeader({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    final avatarSize = context.scale(
      160,
      mobileFactor: 0.75,
      tabletFactor: 0.85,
    );
    final nameStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: context.scaleFont(22),
      fontWeight: FontWeight.w700,
      color: const Color(0xFF052676),
      letterSpacing: 0.6,
    );
    final emailStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: context.scaleFont(14),
      color: Colors.grey.shade700,
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
        backgroundColor: Colors.white,
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
                color: Colors.grey.shade400,
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
      ],
    );
  }
}
