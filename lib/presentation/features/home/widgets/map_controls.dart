import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';

class MapControls extends StatelessWidget {
  final bool isTrafficEnabled;
  final VoidCallback onToggleTraffic;
  final VoidCallback onCenterOnUser;
  final ResponsiveInfo info;

  const MapControls({
    super.key,
    required this.isTrafficEnabled,
    required this.onToggleTraffic,
    required this.onCenterOnUser,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MapControlButton(
          icon: Icons.traffic,
          tooltip: isTrafficEnabled ? 'Hide Traffic' : 'Show Traffic',
          onTap: onToggleTraffic,
          info: info,
          isActive: isTrafficEnabled,
        ),
        SizedBox(height: info.scale(8)),
        _MapControlButton(
          icon: Icons.my_location,
          tooltip: 'Center on my location',
          onTap: onCenterOnUser,
          info: info,
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final ResponsiveInfo info;
  final bool isActive;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    required this.info,
    this.tooltip,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: isActive ? cs.primary : cs.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: Tooltip(
        message: tooltip ?? '',
        preferBelow: false,
        child: Semantics(
          button: true,
          label: tooltip ?? 'Map control',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(info.scale(12)),
              width: info.scale(48),
              height: info.scale(48),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: info.scale(24),
                color: isActive ? cs.onPrimary : cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
