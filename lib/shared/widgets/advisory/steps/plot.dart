import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/providers/advisory.dart';
import 'package:vcroad_v2/shared/utils/map/map.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/utils/dialog/confirmation.dart';
import 'package:vcroad_v2/shared/utils/search/search_place.dart';
import 'package:vcroad_v2/shared/services/place.dart';

class AdvisoryMapPlotter extends StatefulWidget {
  final VoidCallback? onBarangayDetected;

  const AdvisoryMapPlotter({super.key, this.onBarangayDetected});

  @override
  State<AdvisoryMapPlotter> createState() => _AdvisoryMapPlotterState();
}

class _ProviderMapSnapshot {
  final List<List<LatLng>> affected;
  final List<List<LatLng>> alternates;
  final List<LatLng> current;
  final LatLng? center;
  final String? detectedBarangay;
  final String? detectedPlaceName;
  final bool isPlotting;
  final int mapVersion;

  _ProviderMapSnapshot({
    required this.affected,
    required this.alternates,
    required this.current,
    required this.center,
    required this.detectedBarangay,
    required this.detectedPlaceName,
    required this.isPlotting,
    required this.mapVersion,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ProviderMapSnapshot) return false;
    // include version so any map-related change forces rebuild
    return affected.length == other.affected.length &&
        alternates.length == other.alternates.length &&
        current.length == other.current.length &&
        center == other.center &&
        detectedBarangay == other.detectedBarangay &&
        detectedPlaceName == other.detectedPlaceName &&
        isPlotting == other.isPlotting &&
        mapVersion == other.mapVersion;
  }

  @override
  int get hashCode =>
      affected.length ^
      alternates.length ^
      current.length ^
      (center?.latitude.hashCode ?? 0) ^
      (center?.longitude.hashCode ?? 0) ^
      (detectedBarangay?.hashCode ?? 0) ^
      (detectedPlaceName?.hashCode ?? 0) ^
      (isPlotting ? 1 : 0) ^
      mapVersion;
}

class _AdvisoryMapPlotterState extends State<AdvisoryMapPlotter> {
  GoogleMapController? _mapController;
  bool _hasAutoCentered = false;
  bool _isNavigatingToPlace = false;

  static const double _fixedSearchBarHeight = 42.0; // logical px
  static const double _controlSpacing = 12.0;

  Timer? _centerDebounce;

  @override
  void dispose() {
    _centerDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    // Use a Selector to rebuild only when relevant provider state changes.
    return Selector<AdvisoryProvider, _ProviderMapSnapshot>(
      selector: (_, prov) => _ProviderMapSnapshot(
        affected: prov.affectedRoads,
        alternates: prov.alternateRoutes,
        current: prov.currentRoute,
        center: prov.currentCenter,
        detectedBarangay: prov.detectedBarangay,
        detectedPlaceName: prov.detectedPlaceName,
        isPlotting: prov.isPlotting,
        mapVersion: prov.mapTick,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, snap, _) {
        // compute polylines and markers once per snapshot (minimal allocations)
        final Set<Polyline> polylines = <Polyline>{};
        final Set<Marker> markers = <Marker>{};

        if (snap.current.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('current'),
              points: snap.current,
              color: Colors.blue,
              width: 5,
              patterns: [PatternItem.dash(10), PatternItem.gap(5)],
            ),
          );

          markers.add(
            Marker(
              markerId: const MarkerId('start'),
              position: snap.current.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
              infoWindow: const InfoWindow(title: 'Start'),
            ),
          );

          if (snap.current.length > 1) {
            markers.add(
              Marker(
                markerId: const MarkerId('end'),
                position: snap.current.last,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
                infoWindow: const InfoWindow(title: 'Current Point'),
              ),
            );
          }
        }

        for (int i = 0; i < snap.affected.length; i++) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('affected_$i'),
              points: snap.affected[i],
              color: Colors.red,
              width: 6,
            ),
          );
        }

        for (int i = 0; i < snap.alternates.length; i++) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('alternate_$i'),
              points: snap.alternates[i],
              color: Colors.green,
              width: 5,
              patterns: [PatternItem.dash(10), PatternItem.gap(5)],
            ),
          );
        }

        if (snap.center != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('center'),
              position: snap.center!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              ),
              infoWindow: InfoWindow(
                title: 'Advisory Center',
                snippet: snap.detectedBarangay ?? 'Unknown',
              ),
            ),
          );
        }

        // Auto-center ONCE when polylines exist (debounced and scheduled)
        if (!_hasAutoCentered &&
            _mapController != null &&
            (snap.affected.isNotEmpty || snap.alternates.isNotEmpty)) {
          _hasAutoCentered = true;
          _scheduleCentering(snap, responsive);
        }

        return Stack(
          children: [
            GoogleMap(
              key: const ValueKey('advisory_map'),
              onMapCreated: (controller) {
                _mapController ??= controller;
                // If there are polylines and we haven't centered yet, schedule it.
                if (!_hasAutoCentered &&
                    (snap.affected.isNotEmpty || snap.alternates.isNotEmpty)) {
                  _scheduleCentering(snap, responsive);
                }
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(14.7083, 120.9833),
                zoom: 14.0,
              ),
              style: MapUtils.style,
              polylines: polylines,
              markers: markers,
              onTap: snap.isPlotting
                  ? (pos) => context
                        .read<AdvisoryProvider>()
                        .addPointToCurrentRoute(pos)
                  : null,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapType: MapType.normal,
            ),

            // Search overlay (unchanged)
            Positioned(
              top: responsive.scale(16),
              left: responsive.scale(16),
              right: responsive.scale(16),
              child: MapSearch(
                selectedCategory: null,
                onSuggestionSelected: (suggestion) async {
                  await _navigateToSuggestion(suggestion, responsive);
                  // ensure keyboard is dismissed after navigating to suggestion
                  if (context.mounted) FocusScope.of(context).unfocus();
                },
                showCategoryToggle: false,
                topSpacing: 0,
                // match the Positioned left/right padding for consistent sizing
                horizontalPadding: responsive.scale(16),
                // reduce suggestions on mobile for performance/clarity
                maxSuggestions: responsive.isMobile ? 6 : 10,
                elevation: 14,
              ),
            ),

            // Control Panel — simplified offset calculation (logical pixels)
            Positioned(
              top:
                  responsive.scale(16) +
                  _fixedSearchBarHeight +
                  responsive.scale(_controlSpacing),
              right: responsive.scale(16),
              child: _buildControlPanel(
                context,
                context.read<AdvisoryProvider>(),
                responsive,
              ),
            ),

            // Status bar
            if (snap.current.isNotEmpty)
              Positioned(
                bottom: responsive.scale(16),
                left: responsive.scale(16),
                right: responsive.scale(16),
                child: _buildCurrentRouteInfo(
                  context.read<AdvisoryProvider>(),
                  responsive,
                ),
              ),
          ],
        );
      },
    );
  }

  void _scheduleCentering(_ProviderMapSnapshot snap, dynamic responsive) {
    // Debounce repeated center requests (short window)
    _centerDebounce?.cancel();
    _centerDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _mapController == null) return;
      _centerMapOnPolylinesFromSnapshot(snap, responsive);
    });
  }

  Future<void> _centerMapOnPolylinesFromSnapshot(
    _ProviderMapSnapshot snap,
    dynamic responsive,
  ) async {
    try {
      final allPolylines = <LatLng>[];
      for (final poly in snap.affected) {
        allPolylines.addAll(poly);
      }
      for (final poly in snap.alternates) {
        allPolylines.addAll(poly);
      }

      if (allPolylines.isEmpty) return;

      double minLat = allPolylines.first.latitude;
      double maxLat = minLat;
      double minLng = allPolylines.first.longitude;
      double maxLng = minLng;

      for (final p in allPolylines) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final sw = LatLng(minLat, minLng);
      final ne = LatLng(maxLat, maxLng);
      final bounds = LatLngBounds(southwest: sw, northeast: ne);

      await Future.delayed(const Duration(milliseconds: 150));

      final padding = (responsive.isMobile ? 60 : 100).toDouble();

      try {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, padding),
        );
      } catch (_) {
        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLng), 14),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to center map on polylines: $e');
    }
  }

  Future<void> _navigateToSuggestion(
    PlaceSuggestion suggestion,
    dynamic responsive,
  ) async {
    if (_isNavigatingToPlace) return;
    _isNavigatingToPlace = true;
    try {
      final details = await PlaceService.instance.placeDetails(
        suggestion.placeId,
      );
      if (!mounted || details == null) return;

      // Ensure keyboard is dismissed and layout settles (prevents newLatLngBounds
      // from throwing due to zero map size while keyboard is closing).
      if (mounted) FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 180));

      if (_mapController == null) {
        if (kDebugMode) debugPrint('MapController not ready yet');
        return;
      }

      // Prefer viewport (bounds) when available.
      if (details.viewport != null) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(details.viewport!, 64),
          );
          return;
        } catch (e) {
          if (kDebugMode) debugPrint('animate bounds error: $e — falling back');
          // continue to fallback
        }
      }

      // Fallback to location + zoom when viewport is absent.
      if (details.location != null) {
        final zoom = responsive.isMobile ? 16.0 : 18.0;
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: details.location!, zoom: zoom),
            ),
          );
          return;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('animate location error: $e — trying moveCamera');
          }
          try {
            // Try moveCamera (instant) as a last resort
            await _mapController!.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: details.location!, zoom: zoom),
              ),
            );
            return;
          } catch (e2) {
            if (kDebugMode) debugPrint('moveCamera also failed: $e2');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('No geometry found for suggestion ${suggestion.placeId}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('navigateToSuggestion error: $e');
    } finally {
      _isNavigatingToPlace = false;
    }
  }

  Widget _buildControlPanel(
    BuildContext context,
    AdvisoryProvider provider,
    dynamic responsive,
  ) {
    return Card(
      elevation: 4,
      child: Container(
        // Slightly smaller padding and reduced maxWidth for better map area on mobile
        padding: EdgeInsets.all(responsive.scale(10)),
        constraints: BoxConstraints(maxWidth: responsive.isMobile ? 160 : 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode indicator
            Container(
              padding: EdgeInsets.all(responsive.scale(8)),
              decoration: BoxDecoration(
                color: provider.isPlotting
                    ? Colors.blue.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.isPlotting
                        ? Icons.edit_location
                        : Icons.visibility,
                    size: responsive.scale(16),
                    color: provider.isPlotting ? Colors.blue : Colors.grey,
                  ),
                  SizedBox(width: responsive.scale(4)),
                  Expanded(
                    child: Text(
                      provider.isPlotting ? 'Plotting Mode' : 'View Mode',
                      style: TextStyle(
                        fontSize: responsive.scaleFont(11),
                        fontWeight: FontWeight.bold,
                        color: provider.isPlotting ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: responsive.scale(8)),

            // Start plotting button
            if (!provider.isPlotting)
              ElevatedButton.icon(
                onPressed: () => provider.startPlotting(isAffected: true),
                icon: const Icon(
                  Icons.add_location,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  'Plot Affected',
                  style: TextStyle(
                    fontSize: responsive.scaleFont(12),
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: responsive.scale(8)),
                ),
              ),

            // Plotting actions
            if (provider.isPlotting) ...[
              ElevatedButton.icon(
                onPressed: provider.currentRoute.length >= 2
                    ? () async {
                        final success = await provider.snapToRoad();
                        if (!success) {
                          if (context.mounted) {
                            SnackbarUtils.showError(
                              context,
                              provider.error ?? 'Snap failed',
                            );
                          }
                        } else {
                          if (context.mounted) {
                            SnackbarUtils.showSuccess(
                              context,
                              'Snap successful',
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.route, size: 16),
                label: Text(
                  'Snap to Road',
                  style: TextStyle(fontSize: responsive.scaleFont(12)),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: responsive.scale(8)),
                ),
              ),
              SizedBox(height: responsive.scale(6)),
              ElevatedButton.icon(
                onPressed: provider.currentRoute.length >= 2
                    ? () => provider.completeRoute()
                    : null,
                icon: const Icon(Icons.check_circle, size: 16),
                label: Text(
                  'Complete',
                  style: TextStyle(fontSize: responsive.scaleFont(12)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: responsive.scale(8)),
                ),
              ),
              SizedBox(height: responsive.scale(6)),
              OutlinedButton.icon(
                onPressed: () => provider.cancelPlotting(),
                icon: const Icon(Icons.cancel, size: 16),
                label: Text(
                  'Cancel',
                  style: TextStyle(fontSize: responsive.scaleFont(12)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: responsive.scale(8)),
                ),
              ),
            ],

            // Alternate route button
            if (!provider.isPlotting && provider.affectedRoads.isNotEmpty) ...[
              SizedBox(height: responsive.scale(8)),
              OutlinedButton.icon(
                onPressed: () => provider.startPlotting(isAffected: false),
                icon: const Icon(Icons.alt_route, size: 16),
                label: Text(
                  'Add Alternate',
                  style: TextStyle(fontSize: responsive.scaleFont(12)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: responsive.scale(8)),
                ),
              ),
            ],

            // Clear all button
            if (provider.affectedRoads.isNotEmpty ||
                provider.alternateRoutes.isNotEmpty) ...[
              SizedBox(height: responsive.scale(8)),
              OutlinedButton.icon(
                onPressed: () => _confirmClearAll(context, provider),
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: Text(
                  'Clear All',
                  style: TextStyle(fontSize: responsive.scaleFont(12)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: responsive.scale(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentRouteInfo(AdvisoryProvider provider, dynamic responsive) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(responsive.scale(12)),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.blue,
              size: responsive.scale(20),
            ),
            SizedBox(width: responsive.scale(8)),
            Expanded(
              child: Text(
                '${provider.currentRoute.length} point(s) plotted. '
                'Tap to add more or snap to road.',
                style: TextStyle(
                  fontSize: responsive.scaleFont(12),
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    AdvisoryProvider provider,
  ) async {
    if (provider.affectedRoads.isEmpty && provider.alternateRoutes.isEmpty) {
      return; // nothing to clear
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ConfirmationDialog(
        title: 'Clear All Routes?',
        message: 'This will remove all plotted routes. Continue?',
        confirmText: 'Clear',
        cancelText: 'Cancel',
      ),
    );

    if (confirm == true && context.mounted) {
      provider.clearAllPlotting();
      SnackbarUtils.showSuccess(context, 'All routes cleared');
    }
  }
}
