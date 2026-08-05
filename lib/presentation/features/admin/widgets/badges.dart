import 'package:flutter/material.dart';
import 'package:vcroad/data/models/user.dart';

/// Shared, theme-consistent role badge used across account-management views.
class RoleBadge extends StatelessWidget {
  final UserRole role;
  final double fontSize;
  final double? iconSize;

  const RoleBadge({
    super.key,
    required this.role,
    this.fontSize = 12,
    this.iconSize,
  });

  Color get _color => switch (role) {
    UserRole.sysadmin => Colors.purple,
    UserRole.admin => Colors.blue,
    UserRole.user => Colors.teal,
  };

  String get _label => switch (role) {
    UserRole.sysadmin => 'Super Admin',
    UserRole.admin => 'Barangay Admin',
    UserRole.user => 'Road User',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shared status badge (verified / unverified / banned / inactive).
class StatusBadge extends StatelessWidget {
  final bool isVerified;
  final bool isBanned;
  final bool isInactive;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.isVerified,
    required this.isBanned,
    required this.isInactive,
    this.fontSize = 12,
  });

  factory StatusBadge.fromUser(UserDetails user, {double fontSize = 12}) {
    return StatusBadge(
      isVerified: user.isVerified,
      isBanned: user.hasActiveBan,
      isInactive: user.isInactive,
      fontSize: fontSize,
    );
  }

  Color get _color {
    if (isBanned) return Colors.red;
    if (isInactive) return Colors.amber;
    if (isVerified) return Colors.green;
    return Colors.grey;
  }

  String get _label {
    if (isBanned) return 'Banned';
    if (isInactive) return 'Scheduled deletion';
    if (isVerified) return 'Verified';
    return 'Unverified';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: _color),
        const SizedBox(width: 6),
        Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
