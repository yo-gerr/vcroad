import 'package:flutter/material.dart';
import 'package:vcroad_v2/features/account.dart';
import 'package:vcroad_v2/features/advisory.dart';
import 'package:vcroad_v2/features/home.dart';
import 'package:vcroad_v2/features/learn.dart';
import 'package:vcroad_v2/features/lesson.dart';
import 'package:vcroad_v2/features/profile.dart';
import 'package:vcroad_v2/features/report.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/utils/routing/role_ui_config.dart';

class RoleConfig {
  static final Map<UserRole, RoleUIConfig> _configs = {
    UserRole.user: RoleUIConfig(
      navItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.crisis_alert_outlined),
          activeIcon: Icon(Icons.crisis_alert),
          label: 'Report',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.announcement_outlined),
          activeIcon: Icon(Icons.announcement),
          label: 'Advisory',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.school_outlined),
          activeIcon: Icon(Icons.school),
          label: 'Learn',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      railItems: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.crisis_alert_outlined),
          selectedIcon: Icon(Icons.crisis_alert),
          label: Text('Report'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.announcement_outlined),
          selectedIcon: Icon(Icons.announcement),
          label: Text('Advisory'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: Text('Learn'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profile'),
        ),
      ],
      screens: const [Home(), Report(), AdvisoryScreen(), Learn(), Profile()],
      drawerBuilder: (selectedIndex, onTap) => [
        const DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.traffic, size: 48, color: Colors.white),
              SizedBox(height: 8),
              Text(
                'VCRoad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _buildDrawerItem(Icons.home, 'Home', 0, selectedIndex, onTap),
        _buildDrawerItem(Icons.crisis_alert, 'Report', 1, selectedIndex, onTap),
        _buildDrawerItem(
          Icons.announcement,
          'Advisory',
          2,
          selectedIndex,
          onTap,
        ),
        _buildDrawerItem(Icons.school, 'Learn', 3, selectedIndex, onTap),
        const Divider(),
        _buildDrawerItem(Icons.person, 'Profile', 4, selectedIndex, onTap),
      ],
    ),
    UserRole.admin: RoleUIConfig(
      navItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.crisis_alert_outlined),
          activeIcon: Icon(Icons.crisis_alert),
          label: 'Reports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.announcement_outlined),
          activeIcon: Icon(Icons.announcement),
          label: 'Advisory',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.manage_accounts_outlined),
          activeIcon: Icon(Icons.manage_accounts),
          label: 'Accounts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      railItems: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.crisis_alert_outlined),
          selectedIcon: Icon(Icons.crisis_alert),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.announcement_outlined),
          selectedIcon: Icon(Icons.announcement),
          label: Text('Advisory'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts),
          label: Text('Accounts'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profile'),
        ),
      ],
      screens: const [
        Home(), // Admin dashboard
        Report(),
        AdvisoryScreen(),
        Account(),
        Profile(),
      ],
      drawerBuilder: (selectedIndex, onTap) => [
        const DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.deepOrange],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
              SizedBox(height: 8),
              Text(
                'Admin Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _buildDrawerItem(Icons.home, 'Home', 0, selectedIndex, onTap),
        _buildDrawerItem(
          Icons.crisis_alert,
          'Reports',
          1,
          selectedIndex,
          onTap,
        ),
        _buildDrawerItem(
          Icons.announcement,
          'Advisory',
          2,
          selectedIndex,
          onTap,
        ),
        _buildDrawerItem(
          Icons.manage_accounts,
          'Accounts',
          3,
          selectedIndex,
          onTap,
        ),
        const Divider(),
        _buildDrawerItem(Icons.person, 'Profile', 4, selectedIndex, onTap),
      ],
    ),
    UserRole.sysadmin: RoleUIConfig(
      navItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.crisis_alert_outlined),
          activeIcon: Icon(Icons.crisis_alert),
          label: 'Reports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.announcement_outlined),
          activeIcon: Icon(Icons.announcement),
          label: 'Advisory',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.school_outlined),
          activeIcon: Icon(Icons.school),
          label: 'Lessons',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.manage_accounts_outlined),
          activeIcon: Icon(Icons.manage_accounts),
          label: 'Accounts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      railItems: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.crisis_alert_outlined),
          selectedIcon: Icon(Icons.crisis_alert),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.announcement_outlined),
          selectedIcon: Icon(Icons.announcement),
          label: Text('Advisory'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: Text('Lessons'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts),
          label: Text('Accounts'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profile'),
        ),
      ],
      screens: const [
        Home(), // Sysadmin dashboard
        Report(),
        AdvisoryScreen(),
        Lesson(),
        Account(),
        Profile(),
      ],
      drawerBuilder: (selectedIndex, onTap) => [
        const DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.deepPurple],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.security, size: 48, color: Colors.white),
              SizedBox(height: 8),
              Text(
                'Super Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _buildDrawerItem(Icons.home, 'Home', 0, selectedIndex, onTap),
        _buildDrawerItem(
          Icons.crisis_alert,
          'Reports',
          1,
          selectedIndex,
          onTap,
        ),
        _buildDrawerItem(
          Icons.announcement,
          'Advisory',
          2,
          selectedIndex,
          onTap,
        ),
        _buildDrawerItem(Icons.school, 'Lessons', 3, selectedIndex, onTap),
        _buildDrawerItem(
          Icons.manage_accounts,
          'Accounts',
          4,
          selectedIndex,
          onTap,
        ),
        const Divider(),
        _buildDrawerItem(Icons.person, 'Profile', 5, selectedIndex, onTap),
      ],
    ),
  };

  static Widget _buildDrawerItem(
    IconData icon,
    String label,
    int index,
    int selectedIndex,
    void Function(int) onTap,
  ) {
    final isSelected = index == selectedIndex;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.blue : null,
        ),
      ),
      selected: isSelected,
      onTap: () => onTap(index),
    );
  }

  static RoleUIConfig getConfig(UserRole role) {
    return _configs[role]!;
  }
}
