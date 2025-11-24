import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';

/// Immutable data holder for a small stat item.
class StatsUtils {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatsUtils({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

/// Responsive row / grid of stats.
/// - On desktop: lays out as a Row of Expanded StatCards
/// - On mobile/tablet: wraps into two columns (responsive)
class StatsRow extends StatelessWidget {
  final List<StatsUtils> stats;
  final ResponsiveInfo responsive;
  final double spacing;
  final double runSpacing;
  final double cardElevation;

  const StatsRow({
    super.key,
    required this.stats,
    required this.responsive,
    this.spacing = 8,
    this.runSpacing = 8,
    this.cardElevation = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (responsive.isDesktop) {
      return Row(
        children: stats
            .map(
              (s) => Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.scale(spacing / 2),
                  ),
                  child: StatCard(
                    stat: s,
                    responsive: responsive,
                    elevation: cardElevation,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    // mobile / tablet -> two-column grid using Wrap + constrained child width
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxWidth = constraints.maxWidth;
        final columnWidth = (maxWidth - responsive.scale(spacing)) / 2;
        final childWidth = columnWidth.clamp(140.0, maxWidth);

        return Wrap(
          spacing: responsive.scale(spacing),
          runSpacing: responsive.scale(runSpacing),
          children: stats
              .map(
                (s) => SizedBox(
                  width: childWidth,
                  child: StatCard(
                    stat: s,
                    responsive: responsive,
                    elevation: cardElevation,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Individual stat card. Lightweight, uses const-friendly styles.
/// NOTE: intentionally no animations here — updates will replace value text immediately.
class StatCard extends StatelessWidget {
  final StatsUtils stat;
  final ResponsiveInfo responsive;
  final double elevation;

  const StatCard({
    super.key,
    required this.stat,
    required this.responsive,
    this.elevation = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = responsive.isDesktop;
    final double cardPadding = responsive.scale(isDesktop ? 18 : 10);
    final double iconSize = responsive.scale(isDesktop ? 36 : 20);
    final double valueFont = responsive.scaleFont(isDesktop ? 22 : 16);
    final double labelFont = responsive.scaleFont(isDesktop ? 14 : 12);

    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: responsive.scale(isDesktop ? 96 : 56),
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scale(isDesktop ? 12 : 8)),
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(stat.icon, color: stat.color, size: iconSize),
              ),
              SizedBox(width: responsive.scale(isDesktop ? 16 : 10)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Value text is keyed by its string so the framework replaces it immediately
                  Text(
                    stat.value,
                    key: ValueKey<String>(stat.value),
                    style: TextStyle(
                      fontSize: valueFont,
                      fontWeight: FontWeight.bold,
                      color: stat.color,
                    ),
                  ),
                  SizedBox(height: responsive.scale(isDesktop ? 6 : 2)),
                  Text(
                    stat.label,
                    style: TextStyle(
                      fontSize: labelFont,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
