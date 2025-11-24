import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/services/image.dart';

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

  Color _getStatusColor() {
    if (user.isBanned) return Colors.red;
    if (user.isInactive) return Colors.amber; // inactive -> yellow/amber
    if (user.isVerified) return Colors.green;
    return Colors.grey; // unverified -> grey
  }

  String _getStatusLabel() {
    if (user.isBanned) return 'Banned';
    if (user.isInactive) return 'Inactive';
    if (user.isVerified) return 'Verified';
    return 'Unverified';
  }

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
    final nameStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: context.scaleFont(16),
    );
    final emailStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: context.scaleFont(14),
    );
    final barangayStyle = TextStyle(
      color: Colors.grey.shade700,
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
                          color: Colors.grey,
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
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.scale(12),
                      vertical: context.scale(4),
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleLabel(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.scaleFont(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(),
                          size: context.scale(16),
                          color: _getStatusColor(),
                        ),
                        SizedBox(width: context.scale(4)),
                        Text(
                          _getStatusLabel(),
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontSize: context.scaleFont(12),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (user.role) {
      case UserRole.sysadmin:
        return Colors.purple;
      case UserRole.admin:
        return Colors.blue;
      case UserRole.user:
        return Colors.teal;
    }
  }

  String _getRoleLabel() {
    switch (user.role) {
      case UserRole.sysadmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Barangay Admin';
      case UserRole.user:
        return 'Road User';
    }
  }

  IconData _getStatusIcon() {
    if (user.isBanned) return Icons.block;
    if (user.isInactive) return Icons.schedule_outlined;
    if (user.isVerified) return Icons.verified;
    return Icons.pending_outlined;
  }
}
