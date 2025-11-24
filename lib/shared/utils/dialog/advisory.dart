import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vcroad_v2/shared/models/advisory.dart';
import 'package:vcroad_v2/shared/utils/image/preview.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/map/map.dart';
import 'package:vcroad_v2/shared/utils/map/interaction_controller.dart';

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
            color: Colors.white,
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
                      _buildStatusBadge(context, responsive),
                      SizedBox(height: responsive.scale(16)),

                      // Location info
                      _buildLocationSection(responsive),
                      SizedBox(height: responsive.scale(16)),

                      // Description
                      _buildSection(
                        responsive,
                        'Description',
                        Icons.description,
                        Colors.blue,
                        Text(
                          advisory.reason,
                          style: TextStyle(
                            fontSize: responsive.scaleFont(14),
                            height: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: responsive.scale(16)),

                      // Schedule
                      _buildScheduleSection(context, responsive),
                      SizedBox(height: responsive.scale(16)),

                      // Contractor (if applicable)
                      if (advisory.contractor != null) ...[
                        _buildContractorSection(responsive),
                        SizedBox(height: responsive.scale(16)),
                      ],

                      // Routes info
                      _buildRoutesSection(responsive),
                      SizedBox(height: responsive.scale(16)),

                      // Mini map
                      if (advisory.affectedRoads != null &&
                          advisory.affectedRoads!.isNotEmpty)
                        _buildMiniMap(responsive),
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
    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: (category?.color ?? const Color(0xFF001278)).withValues(
          alpha: 0.1,
        ),
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
                      _getIconForCategory(category.id),
                      color: Colors.white,
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
                    color: const Color(0xFF001278),
                  ),
                ),
                Text(
                  'Advisory Details',
                  style: TextStyle(
                    fontSize: responsive.scaleFont(12),
                    color: Colors.grey.shade600,
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
    final heroTag = 'advisory_preview${identityHashCode(imageUrl)}';

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.grey.shade50,
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
                        color: Colors.grey.shade100,
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
                      color: Colors.grey.shade200,
                      height: maxHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: responsive.scale(36),
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: responsive.scale(8)),
                          Text(
                            'Image unavailable',
                            style: TextStyle(
                              fontSize: responsive.scaleFont(12),
                              color: Colors.grey.shade600,
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

  Widget _buildStatusBadge(BuildContext context, dynamic responsive) {
    // Use persisted status only
    final status = advisory.status;

    Color color;
    IconData icon;
    String label;

    switch (status) {
      case AdvisoryStatus.active:
        color = Colors.green;
        icon = Icons.play_circle_filled;
        label = 'Active';
        break;
      case AdvisoryStatus.scheduled:
        color = Colors.blue;
        icon = Icons.schedule;
        label = 'Scheduled';
        break;
      case AdvisoryStatus.expired:
        color = Colors.grey;
        icon = Icons.history;
        label = 'Expired';
        break;
      case AdvisoryStatus.inactive:
        color = Colors.grey;
        icon = Icons.pause;
        label = 'Inactive';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scale(12),
        vertical: responsive.scale(8),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: responsive.scale(18), color: color),
          SizedBox(width: responsive.scale(6)),
          Text(
            label,
            style: TextStyle(
              fontSize: responsive.scaleFont(13),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(dynamic responsive) {
    return _buildSection(
      responsive,
      'Location',
      Icons.location_on,
      Colors.red,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(responsive, 'Barangay', advisory.barangay, Icons.place),
          if (advisory.placeName != null) ...[
            SizedBox(height: responsive.scale(8)),
            _buildInfoRow(
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
      responsive,
      'Schedule',
      Icons.calendar_today,
      Colors.orange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
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
              responsive,
              'Duration',
              '${DateFormat('MMM dd, yyyy').format(advisory.startDate)} - ${DateFormat('MMM dd, yyyy').format(advisory.endDate)}',
              Icons.date_range,
            ),
            SizedBox(height: responsive.scale(8)),
          ],

          if (advisory.scheduleType == AdvisoryScheduleType.recurring) ...[
            _buildInfoRow(
              responsive,
              'Days',
              _formatWeekdays(advisory.weekdays ?? []),
              Icons.repeat,
            ),
            if (advisory.recurringStartTime != null &&
                advisory.recurringEndTime != null) ...[
              SizedBox(height: responsive.scale(8)),
              _buildInfoRow(
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

  Widget _buildContractorSection(dynamic responsive) {
    return _buildSection(
      responsive,
      'Contractor',
      Icons.business,
      Colors.deepOrange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            responsive,
            'Company',
            advisory.contractor!,
            Icons.business_center,
          ),
          if (advisory.contractorContact != null) ...[
            SizedBox(height: responsive.scale(8)),
            _buildInfoRow(
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

  Widget _buildRoutesSection(dynamic responsive) {
    final affectedCount = advisory.affectedRoads?.length ?? 0;
    final alternateCount = advisory.alternateRoutes?.length ?? 0;

    return _buildSection(
      responsive,
      'Routes',
      Icons.alt_route,
      Colors.purple,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            responsive,
            'Affected Roads',
            '$affectedCount route${affectedCount != 1 ? 's' : ''}',
            Icons.warning_amber,
          ),
          SizedBox(height: responsive.scale(8)),
          _buildInfoRow(
            responsive,
            'Alternate Routes',
            '$alternateCount route${alternateCount != 1 ? 's' : ''}',
            Icons.directions,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap(dynamic responsive) {
    return _buildSection(
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
    dynamic responsive,
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.scale(8)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: responsive.scale(20)),
              ),
              SizedBox(width: responsive.scale(12)),
              Text(
                title,
                style: TextStyle(
                  fontSize: responsive.scaleFont(16),
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
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
    dynamic responsive,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: responsive.scale(16), color: Colors.grey.shade600),
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
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: responsive.scale(2)),
              Text(
                value,
                style: TextStyle(
                  fontSize: responsive.scaleFont(14),
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, dynamic responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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

  IconData _getIconForCategory(String categoryId) {
    switch (categoryId) {
      case 'road_closure':
        return Icons.block;
      case 'stop_and_go':
        return Icons.traffic;
      case 'one_way':
        return Icons.arrow_forward;
      case 'construction':
        return Icons.construction;
      case 'partial_lane':
        return Icons.remove_road;
      case 'event':
        return Icons.event;
      case 'emergency':
        return Icons.warning;
      default:
        return Icons.info;
    }
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
  GoogleMapController? _controller;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _buildPolylines();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  void _buildPolylines() {
    final polylines = <Polyline>{};

    // Affected roads
    if (widget.advisory.affectedRoads != null) {
      for (int i = 0; i < widget.advisory.affectedRoads!.length; i++) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('affected_$i'),
            points: widget.advisory.affectedRoads![i],
            color: Colors.red,
            width: 5,
          ),
        );
      }
    }

    // Alternate routes
    if (widget.advisory.alternateRoutes != null) {
      for (int i = 0; i < widget.advisory.alternateRoutes!.length; i++) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('alternate_$i'),
            points: widget.advisory.alternateRoutes![i],
            color: Colors.green,
            width: 4,
            patterns: [PatternItem.dash(10), PatternItem.gap(5)],
          ),
        );
      }
    }

    setState(() => _polylines = polylines);
  }

  Future<void> _fitBounds() async {
    if (_controller == null) return;

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

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    } catch (_) {
      // Fallback
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLng), 14),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (controller) {
        _controller = controller;
        _fitBounds();
      },
      initialCameraPosition: CameraPosition(
        target: widget.advisory.center ?? const LatLng(14.7083, 120.9833),
        zoom: 14,
      ),
      style: MapUtils.style,
      polylines: _polylines,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      liteModeEnabled: true, // Lighter map for dialogs
    );
  }

  @override
  void dispose() {
    // Do NOT dispose controller on web
    super.dispose();
  }
}
