import 'package:flutter/material.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/data/repositories/image.dart';
import 'package:vcroad/presentation/features/admin/widgets/badges.dart';

class UserListItem extends StatelessWidget {
  final UserDetails user;
  final VoidCallback onTap;
  final String? avatarUrl;

  const UserListItem({
    super.key,
    required this.user,
    required this.onTap,
    this.avatarUrl,
  });

  Widget _buildAvatar(BuildContext context) {
    final double logicalDiameter = context.scale(48);
    final int cacheWidth = context.cacheWidthForImage(logicalDiameter);

    return ImageService.buildCachedAvatar(
      imageUrl: avatarUrl,
      radius: logicalDiameter / 2,
      cacheWidth: cacheWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: context.scaleFont(16),
    );
    final emailStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: context.scaleFont(14),
    );
    final barangayStyle = TextStyle(
      color: colorScheme.onSurfaceVariant,
      fontSize: context.scaleFont(13),
    );

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: context.scale(16),
        vertical: context.scale(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(context.scale(16)),
          child: Row(
            children: [
              _buildAvatar(context),
              SizedBox(width: context.scale(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: nameStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.scale(4)),
                    Text(
                      user.email,
                      style: emailStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.scale(6)),
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: context.scale(14),
                          color: colorScheme.outline,
                        ),
                        SizedBox(width: context.scale(6)),
                        Expanded(
                          child: Text(
                            user.barangay.name,
                            style: barangayStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.scale(12)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RoleBadge(role: user.role),
                  SizedBox(height: context.scale(8)),
                  if ((user.flaggedReportsCount) > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.scale(8),
                        vertical: context.scale(4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(
                          alpha: 0.12,
                        ), // flagged -> orange
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag,
                            size: context.scale(14),
                            color: Colors.orange,
                          ),
                          SizedBox(width: context.scale(6)),
                          Text(
                            '${user.flaggedReportsCount}',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: context.scaleFont(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    StatusBadge.fromUser(user, fontSize: context.scaleFont(12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
