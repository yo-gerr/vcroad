import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/presentation/shared/widgets/image/preview.dart';
import 'package:vcroad/presentation/shared/widgets/advisory_status_badge.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/map/interaction_controller.dart';

/// Reusable, responsive dialog for displaying advisory details
/// with image, map, schedule, and metadata
class AdvisoryDetailsDialog extends StatelessWidget {
  final Advisory advisory;

  const AdvisoryDetailsDialog({super.key, required this.advisory});

  /// Show dialog helper
  static Future<void> show(BuildContext context, Advisory advisory) async {
    final controller = MapInteractionController.instance;
    controller.acquire();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AdvisoryDetailsDialog(advisory: advisory),
      );
    } finally {
      controller.release();
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final scheme = Theme.of(context).colorScheme;
    final category = AdvisoryCategory.findById(advisory.advisoryType);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: responsive.scale(16),
        vertical: responsive.scale(24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: responsive.isDesktop ? 800 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildHeader(context, responsive, category),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(responsive.scale(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image (if available)
                      if (advisory.imageUrl != null) ...[
                        _buildImage(context, responsive, advisory.imageUrl!),
                        SizedBox(height: responsive.scale(16)),
                      ],

                      // Status badge
                      AdvisoryStatusBadge(
                        status: advisory.status,
                        responsive: responsive,
                        iconSize: 16,
                        paddingFactor: 1.3,
                      ),
                      SizedBox(height: responsive.scale(16)),

                      // Location info
                      _buildLocationSection(context, responsive),
                      SizedBox(height: responsive.scale(16)),

                      // Description
                      _buildSection(
                        context,
                        responsive,
                        'Description',
                        Icons.description,
                        Colors.blue,
                        Text(
                          advisory.reason,
                          style: TextStyle(
                            fontSize: responsive.scaleFont(14),
                            height: 1.5,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      SizedBox(height: responsive.scale(16)),

                      // Schedule
                      _buildScheduleSection(context, responsive),
                      SizedBox(height: responsive.scale(16)),

                      // Contractor (if applicable)
                      if (advisory.contractor != null) ...[
                        _buildContractorSection(context, responsive),
                        SizedBox(height: responsive.scale(16)),
                      ],

                      // Routes info
                      _buildRoutesSection(context, responsive),
                      SizedBox(height: responsive.scale(16)),

                      // Mini map
                      if (advisory.affectedRoads != null &&
                          advisory.affectedRoads!.isNotEmpty)
                        _buildMiniMap(context, responsive),
                    ],
                  ),
                ),
              ),

              // Footer actions
              _buildFooter(context, responsive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic responsive,
    AdvisoryCategory? category,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = category?.color ?? AppColors.primary;

    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          if (category != null)
            Container(
              width: responsive.scale(48),
              height: responsive.scale(48),
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: category.iconPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        category.iconPath,
                        width: responsive.scale(32),
                        height: responsive.scale(32),
                        fit: BoxFit.contain,
                      ),
                    )
                  : Icon(
                      AdvisoryCategory.iconFor(category.id),
                      color: categoryColor.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                      size: responsive.scale(28),
                    ),
            ),
          SizedBox(width: responsive.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category?.title ?? advisory.advisoryType,
                  style: TextStyle(
                    fontSize: responsive.scaleFont(18),
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryAdaptive(context),
                  ),
                ),
                Text(
                  'Advisory Details',
                  style: TextStyle(
                    fontSize: responsive.scaleFont(12),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  // Pass BuildContext so we can precache and show the preview safely.
  Widget _buildImage(
    BuildContext context,
    dynamic responsive,
    String imageUrl,
  ) {
    // Limit the visual size while preserving aspect ratio. Wrap with Hero + GestureDetector
    // and show full-screen preview on tap. Precache image before showing preview for smoother UX.
    final maxHeight = (responsive.scale(160)).clamp(80.0, 320.0) as double;
    final heroTag = 'advisory_preview_${advisory.advisoryId}';
    final scheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            minHeight: 80,
            maxWidth: responsive.isDesktop ? 760 : double.infinity,
          ),
          // Use a Stack so we can overlay a small fullscreen preview button at the bottom-right.
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Primary tap area (image + hero for smooth transition)
              GestureDetector(
                onTap: () async {
                  try {
                    final overlayCtx =
                        Navigator.of(context).overlay?.context ?? context;
                    await precacheImage(NetworkImage(imageUrl), overlayCtx);
                  } catch (_) {}
                  if (!context.mounted) return;
                  await showImagePreviewDialog(context, imageUrl);
                },
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: maxHeight,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      final value = progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                                (progress.expectedTotalBytes ?? 1)
                          : null;
                      return Container(
                        color: scheme.surfaceContainerHighest,
                        child: Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, st) => Container(
                      color: scheme.surfaceContainerHighest,
                      height: maxHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: responsive.scale(36),
                            color: scheme.outline,
                          ),
                          SizedBox(height: responsive.scale(8)),
                          Text(
                            'Image unavailable',
                            style: TextStyle(
                              fontSize: responsive.scaleFont(12),
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom-right fullscreen icon
              Positioned(
                right: 8,
                bottom: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      try {
                        final overlayCtx =
                            Navigator.of(context).overlay?.context ?? context;
                        await precacheImage(NetworkImage(imageUrl), overlayCtx);
                      } catch (_) {}
                      if (!context.mounted) return;
                      await showImagePreviewDialog(context, imageUrl);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(responsive.scale(8)),
                      child: Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: responsive.scale(18),
                        semanticLabel: 'Preview fullscreen',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, dynamic responsive) {
    return _buildSection(
      context,
      responsive,
      'Location',
      Icons.location_on,
      Colors.red,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(context, responsive, 'Barangay', advisory.barangay, Icons.place),
          if (advisory.placeName != null) ...[
            SizedBox(height: responsive.scale(8)),
            _buildInfoRow(
              context,
              responsive,
              'Address',
              advisory.placeName!,
              Icons.map,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSection(BuildContext context, dynamic responsive) {
    return _buildSection(
      context,
      responsive,
      'Schedule',
      Icons.calendar_today,
      Colors.orange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            responsive,
            'Type',
            advisory.scheduleType == AdvisoryScheduleType.oneTime
                ? 'One-Time'
                : 'Recurring',
            Icons.event,
          ),
          SizedBox(height: responsive.scale(8)),

          // Show duration only for one-time advisories. Recurring advisories
          // do not display start/end date range (these are nulled on save).
          if (advisory.scheduleType == AdvisoryScheduleType.oneTime) ...[
            _buildInfoRow(
              context,
              responsive,
              'Duration',
              '${DateFormat('MMM dd, yyyy').format(advisory.startDate)} - ${DateFormat('MMM dd, yyyy').format(advisory.endDate)}',
              Icons.date_range,
            ),
            SizedBox(height: responsive.scale(8)),
          ],

          if (advisory.scheduleType == AdvisoryScheduleType.recurring) ...[
            _buildInfoRow(
              context,
              responsive,
              'Days',
              _formatWeekdays(advisory.weekdays ?? []),
              Icons.repeat,
            ),
            if (advisory.recurringStartTime != null &&
                advisory.recurringEndTime != null) ...[
              SizedBox(height: responsive.scale(8)),
              _buildInfoRow(
                context,
                responsive,
                'Time',
                '${advisory.recurringStartTime!.format(context)} - ${advisory.recurringEndTime!.format(context)}',
                Icons.access_time,
              ),
            ],
            SizedBox(height: responsive.scale(8)),
          ],
        ],
      ),
    );
  }

  Widget _buildContractorSection(BuildContext context, dynamic responsive) {
    return _buildSection(
      context,
      responsive,
      'Contractor',
      Icons.business,
      Colors.deepOrange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            responsive,
            'Company',
            advisory.contractor!,
            Icons.business_center,
          ),
          if (advisory.contractorContact != null) ...[
            SizedBox(height: responsive.scale(8)),
            _buildInfoRow(
              context,
              responsive,
              'Contact',
              advisory.contractorContact!,
              Icons.phone,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoutesSection(BuildContext context, dynamic responsive) {
    final affectedCount = advisory.affectedRoads?.length ?? 0;
    final alternateCount = advisory.alternateRoutes?.length ?? 0;

    return _buildSection(
      context,
      responsive,
      'Routes',
      Icons.alt_route,
      Colors.purple,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            responsive,
            'Affected Roads',
            '$affectedCount route${affectedCount != 1 ? 's' : ''}',
            Icons.warning_amber,
          ),
          SizedBox(height: responsive.scale(8)),
          _buildInfoRow(
            context,
            responsive,
            'Alternate Routes',
            '$alternateCount route${alternateCount != 1 ? 's' : ''}',
            Icons.directions,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap(BuildContext context, dynamic responsive) {
    return _buildSection(
      context,
      responsive,
      'Map View',
      Icons.map,
      Colors.teal,
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: responsive.scale(250),
          child: RepaintBoundary(child: _AdvisoryMiniMap(advisory: advisory)),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    dynamic responsive,
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Color.lerp(color, Colors.white, 0.35)! : color;

    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scale(8)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: responsive.scale(20)),
              ),
              SizedBox(width: responsive.scale(12)),
              Text(
                title,
                style: TextStyle(
                  fontSize: responsive.scaleFont(16),
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.scale(12)),
          content,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    dynamic responsive,
    String label,
    String value,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: responsive.scale(16), color: scheme.onSurfaceVariant),
        SizedBox(width: responsive.scale(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: responsive.scaleFont(12),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: responsive.scale(2)),
              Text(
                value,
                style: TextStyle(
                  fontSize: responsive.scaleFont(14),
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, dynamic responsive) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 18),
              label: Text(
                'Close',
                style: TextStyle(fontSize: responsive.scaleFont(14)),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: responsive.scale(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeekdays(List<int> days) {
    if (days.isEmpty) return 'None';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => weekdays[d - 1]).join(', ');
  }
}

/// Mini embedded map showing advisory polylines
class _AdvisoryMiniMap extends StatefulWidget {
  final Advisory advisory;

  const _AdvisoryMiniMap({required this.advisory});

  @override
  State<_AdvisoryMiniMap> createState() => _AdvisoryMiniMapState();
}

class _AdvisoryMiniMapState extends State<_AdvisoryMiniMap> {
  final MapController _controller = MapController();
  List<Polyline> _polylines = [];

  @override
  void initState() {
    super.initState();
    _buildPolylines();
  }

  void _buildPolylines() {
    final polylines = <Polyline>[];

    // Affected roads
    if (widget.advisory.affectedRoads != null) {
      for (int i = 0; i < widget.advisory.affectedRoads!.length; i++) {
        polylines.add(
          Polyline(
            points: widget.advisory.affectedRoads![i],
            color: Colors.red,
            strokeWidth: 5,
          ),
        );
      }
    }

    // Alternate routes
    if (widget.advisory.alternateRoutes != null) {
      for (int i = 0; i < widget.advisory.alternateRoutes!.length; i++) {
        polylines.add(
          Polyline(
            points: widget.advisory.alternateRoutes![i],
            color: Colors.green,
            strokeWidth: 4,
          ),
        );
      }
    }

    setState(() => _polylines = polylines);
  }

  void _fitBounds() {
    final allPoints = <LatLng>[];
    for (final poly in _polylines) {
      allPoints.addAll(poly.points);
    }

    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = minLat;
    double minLng = allPoints.first.longitude;
    double maxLng = minLng;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Degenerate geometry (single-point route): a zero-area bounds has no
    // derivable zoom, so fall back to a centered, fixed zoom instead.
    if (minLat == maxLat && minLng == maxLng) {
      _controller.move(LatLng(minLat, minLng), 14);
      return;
    }

    // Fit the camera to the full plot so every affected and alternate route
    // is visible at the correct zoom. Padding keeps the stroke widths from
    // being clipped at the map edges.
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    _controller.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(24)),
    );

    // Zoom out one full level (~2x) around the fitted center so the whole
    // plot stays in view with more surrounding context.
    final fitted = _controller.camera;
    final zoomOut = (fitted.zoom - 1).clamp(2.0, 18.0).toDouble();
    _controller.move(fitted.center, zoomOut);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: widget.advisory.center ?? const LatLng(14.7083, 120.9833),
        initialZoom: 14.0,
        onMapReady: _fitBounds,
        // Read-only overview: keep gestures from fighting the dialog's
        // vertical scroll and keep the view fitted to the plot.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      mapController: _controller,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.vcroad.app',
        ),
        PolylineLayer(polylines: _polylines),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
