import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vcroad_v2/app/app.dart';
import 'package:vcroad_v2/shared/models/user.dart';

/// Centralized role-based routing utility
class RoleRouter {
  // Mapping roles to routes
  static final Map<UserRole, String> _roleRoutes = {
    UserRole.user: '/roaduser',
    UserRole.admin: '/barangayadmin',
    UserRole.sysadmin: '/superadmin',
  };

  // Mapping roles to screens
  static Map<UserRole, Widget> _roleScreens(UserDetails? userDetails) => {
    UserRole.user: AppScreen(role: UserRole.user, userDetails: userDetails),
    UserRole.admin: AppScreen(role: UserRole.admin, userDetails: userDetails),
    UserRole.sysadmin: AppScreen(
      role: UserRole.sysadmin,
      userDetails: userDetails,
    ),
  };

  /// Returns the route path for a given role.
  static String route(UserRole role) => _roleRoutes[role]!;

  /// Navigates to the appropriate screen based on role.
  static void navigate(
    BuildContext context,
    UserRole role, {
    UserDetails? userDetails,
  }) {
    if (context.mounted) {
      context.pushReplacement(route(role), extra: userDetails);
    }
  }

  /// Returns the screen widget for direct navigation (if not using named routes).
  static Widget screen(UserRole role, {UserDetails? userDetails}) {
    return _roleScreens(userDetails)[role]!;
  }
}
