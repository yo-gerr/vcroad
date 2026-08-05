import 'package:flutter/material.dart';
import 'package:vcroad/data/models/advisory.dart';

/// Reusable pill badge showing an advisory's persisted status.
///
/// Colors and labels come from [AdvisoryStatus] (single source of truth) so
/// every surface — cards, detail dialogs, etc. — renders identically.
class AdvisoryStatusBadge extends StatelessWidget {
  final AdvisoryStatus status;
  final dynamic responsive;
  final double iconSize;
  final double paddingFactor;

  const AdvisoryStatusBadge({
    super.key,
    required this.status,
    required this.responsive,
    this.iconSize = 14,
    this.paddingFactor = 1.0,
  });

  /// Foreground color for badge text/icon. Most status colors already clear a
  /// ~3:1 contrast against the light chip background, but the scheduled orange
  /// (0xFFF57C00) is too light for small bold text, so it is darkened here.
  /// The tint/background still uses [AdvisoryStatus.color] (single source).
  static Color foreground(AdvisoryStatus status) {
    return switch (status) {
      AdvisoryStatus.scheduled => const Color(0xFFB26500),
      _ => status.color,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    final fg = foreground(status);

    final IconData icon = switch (status) {
      AdvisoryStatus.active => Icons.play_circle_filled,
      AdvisoryStatus.scheduled => Icons.schedule,
      AdvisoryStatus.expired => Icons.history,
      AdvisoryStatus.inactive => Icons.pause,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scale(8 * paddingFactor),
        vertical: responsive.scale(4 * paddingFactor),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12 * paddingFactor),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: responsive.scale(iconSize), color: fg),
          SizedBox(width: responsive.scale(4 * paddingFactor)),
          Text(
            status.label,
            style: TextStyle(
              fontSize: responsive.scaleFont(11 * paddingFactor),
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
