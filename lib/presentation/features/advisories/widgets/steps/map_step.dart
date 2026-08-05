import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/presentation/providers/advisory.dart';
import 'package:vcroad/presentation/features/advisories/widgets/create_advisory.dart';
import 'package:vcroad/presentation/features/advisories/widgets/steps/plot.dart';

class MapPage extends StatefulWidget {
  final AdvisoryFormData formData;
  final dynamic responsive;

  const MapPage({super.key, required this.formData, required this.responsive});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  bool _collapsed = false;

  void _toggleCollapsed() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final responsive = widget.responsive;

    return Column(
      children: [
        // Collapsible Instructions Header
        Material(
          color: AppColors.primaryAdaptive(
            context,
          ).withValues(alpha: Theme.of(context).brightness == Brightness.dark
              ? 0.16
              : 0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scale(16),
              vertical: responsive.scale(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: AppColors.primaryAdaptive(context),
                      size: responsive.scale(24),
                    ),
                    SizedBox(width: responsive.scale(8)),
                    Expanded(
                      child: Text(
                        'Plot Affected Roads',
                        style: TextStyle(
                          fontSize: responsive.scaleFont(18),
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryAdaptive(context),
                        ),
                      ),
                    ),
                    // collapse toggle
                    IconButton(
                      onPressed: _toggleCollapsed,
                      tooltip: _collapsed
                          ? 'Show instructions'
                          : 'Hide instructions',
                      icon: AnimatedRotation(
                        turns: _collapsed ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          _collapsed
                              ? Icons.expand_more
                              : Icons.expand_less,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                // Animated details -> shrinks to zero when collapsed to give more map space
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: _collapsed
                        ? const BoxConstraints(maxHeight: 0)
                        : BoxConstraints(),
                    child: _collapsed
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: EdgeInsets.only(top: responsive.scale(8)),
                            child: Text(
                              '1. Tap on map to plot affected road points\n'
                              '2. Use "Snap to Road" to align with actual roads\n'
                              '3. Complete route and add alternate routes if needed',
                              style: TextStyle(
                                fontSize: responsive.scaleFont(13),
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Map
        Expanded(
          child: RepaintBoundary(
            child: AdvisoryMapPlotter(
              onBarangayDetected: () => widget.formData.markChanged(),
            ),
          ),
        ),

        // Status bar
        Consumer<AdvisoryProvider>(
          builder: (context, provider, _) {
            final affectedCount = provider.affectedRoads.length;
            final alternateCount = provider.alternateRoutes.length;
            final barangay = provider.detectedBarangay;

            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(responsive.scale(12)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              // Use a Wrap so chips flow and wrap on small screens. Constrain per-chip width
              // so long labels truncate gracefully. A horizontal scroll fallback keeps things reachable.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final chipMaxWidth = responsive.isMobile
                      ? (maxWidth * 0.46).clamp(120.0, maxWidth)
                      : 240.0;

                  final chips = <Widget>[
                    _buildStatusChip(
                      Icons.warning_amber,
                      '$affectedCount Affected',
                      Colors.red,
                      responsive,
                      maxWidth: chipMaxWidth,
                    ),
                    _buildStatusChip(
                      Icons.alt_route,
                      '$alternateCount Alternate',
                      Colors.blue,
                      responsive,
                      maxWidth: chipMaxWidth,
                    ),
                  ];

                  if (barangay != null) {
                    chips.add(
                      _buildStatusChip(
                        Icons.location_on,
                        barangay,
                        Colors.green,
                        responsive,
                        maxWidth: chipMaxWidth,
                      ),
                    );
                  }
                  if (provider.detectedPlaceName != null) {
                    chips.add(
                      _buildStatusChip(
                        Icons.place,
                        provider.detectedPlaceName!,
                        Colors.teal,
                        responsive,
                        maxWidth: chipMaxWidth,
                      ),
                    );
                  }

                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: responsive.scale(8),
                    runSpacing: responsive.scale(8),
                    children: chips,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    IconData icon,
    String label,
    Color color,
    dynamic responsive, {
    double? maxWidth,
  }) {
    // Keep chip layout compact on mobile; allow truncation for long texts.
    final iconSize = responsive.isMobile
        ? responsive.scale(14)
        : responsive.scale(16);
    final fontSize = responsive.isMobile
        ? responsive.scaleFont(11)
        : responsive.scaleFont(12);

    // Brighten accent colors in dark mode so the chip stays readable on the
    // darker status-bar surface.
    final Color chipColor =
        Theme.of(context).brightness == Brightness.dark
        ? (Color.lerp(color, Colors.white, 0.35) ?? color)
        : color;

    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scale(12),
        vertical: responsive.scale(8),
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: chipColor),
          SizedBox(width: responsive.scale(6)),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      );
    }
    return child;
  }
}
