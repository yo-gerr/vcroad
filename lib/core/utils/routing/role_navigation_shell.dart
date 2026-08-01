import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/routing/role_ui_config.dart';

class RoleNavigationShell extends StatelessWidget {
  final RoleUIConfig config;
  final bool hasWideLayout;
  final int selectedIndex;
  final void Function(int) onItemSelected;
  final PageStorageBucket bucket;
  final int? reportsBadgeCount; // new optional badge count for reports (admins)

  const RoleNavigationShell({
    super.key,
    required this.config,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.bucket,
    this.hasWideLayout = false,
    this.reportsBadgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = hasWideLayout;

    // Helper to wrap an icon with badge when index matches "reports" (index 1)
    Widget maybeBadge(Widget icon, int index) {
      final count = reportsBadgeCount ?? 0;
      if (index == 1 && count > 0) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -6,
              top: -6,
              child: Semantics(
                label: '$count pending reports',
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return icon;
    }

    return Scaffold(
      drawer: isWide
          ? null
          : Drawer(
              child: ListView(
                children: config.drawerBuilder(selectedIndex, onItemSelected),
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onItemSelected,
              labelType: NavigationRailLabelType.all,
              destinations: List<NavigationRailDestination>.generate(
                config.railItems.length,
                (i) {
                  final dest = config.railItems[i];
                  return NavigationRailDestination(
                    icon: maybeBadge(dest.icon, i),
                    selectedIcon: maybeBadge(dest.selectedIcon, i),
                    label: dest.label,
                  );
                },
              ),
            ),
          Expanded(
            child: PageStorage(
              bucket: bucket,
              child: IndexedStack(
                index: selectedIndex.clamp(0, config.screens.length - 1),
                children: config.screens,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: onItemSelected,
              type: BottomNavigationBarType.fixed,
              items: List<BottomNavigationBarItem>.generate(
                config.navItems.length,
                (i) {
                  final item = config.navItems[i];
                  return BottomNavigationBarItem(
                    icon: maybeBadge(item.icon, i),
                    activeIcon: maybeBadge(item.activeIcon, i),
                    label: item.label,
                  );
                },
              ),
            ),
    );
  }
}
