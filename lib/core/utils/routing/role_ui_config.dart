import 'package:flutter/material.dart';

class RoleUIConfig {
  final List<BottomNavigationBarItem> navItems;
  final List<NavigationRailDestination> railItems;
  final List<Widget> screens;
  final List<Widget> Function(int selectedIndex, void Function(int) onTap)
  drawerBuilder;

  const RoleUIConfig({
    required this.navItems,
    required this.railItems,
    required this.screens,
    required this.drawerBuilder,
  });
}
