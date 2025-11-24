import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vcroad_v2/shared/utils/map/map.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/services/marker.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/utils/format/text.dart';

class LocationStep extends StatefulWidget {
  final LatLng? userLocation;
  final String? address;
  final VoidCallback onRetryLocation;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool isLocating; // <--- new

  const LocationStep({
    super.key,
    required this.userLocation,
    required this.address,
    required this.onRetryLocation,
    required this.onBack,
    required this.onSubmit,
    this.isLocating = false,
  });

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _userMarkerIcon;
  Set<Polyline> _barangayPolylines = {};
  bool? _isInsideBarangay; // null = not yet detected
  bool _isCheckingBarangay = false; // ✅ Add loading state for barangay check
  String? _detectedBarangay; // ✅ Store detected barangay name

  static const double _locationZoom = 18;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserMarker();
      _loadBarangayPolylinesAndCheck(); // ✅ Combined method
    });
  }

  Future<void> _loadUserMarker() async {
    BitmapDescriptor icon;
    try {
      icon = await MarkerService.instance.getCustomUserMarker(
        context,
        logicalSize: 32.0,
      );
    } catch (_) {
      icon = await MarkerService.instance.getUserMarker();
    }
    if (mounted) {
      setState(() {
        _userMarkerIcon = icon;
      });
    }
  }

  Future<void> _loadBarangayPolylinesAndCheck() async {
    setState(() {
      _isCheckingBarangay = true;
    });

    try {
      // ✅ Ensure barangays are loaded before checking
      if (!BarangayService().isLoaded) {
        await BarangayService().loadBarangays();
      }

      final polylines = BarangayService().generateBarangayPolylines(
        color: Colors.blue.withValues(alpha: 0.5),
        width: 3,
      );

      if (mounted) {
        setState(() {
          _barangayPolylines = polylines;
        });
        // Check barangay after polygons are loaded
        await _checkUserBarangay();
      }
    } catch (e) {
      debugPrint('❌ Error loading barangay data: $e');
      if (mounted) {
        setState(() {
          _isInsideBarangay = null;
          _isCheckingBarangay = false;
        });
      }
    }
  }

  Future<void> _checkUserBarangay() async {
    if (widget.userLocation == null) {
      setState(() {
        _isInsideBarangay = null;
        _detectedBarangay = null;
        _isCheckingBarangay = false;
      });
      return;
    }

    try {
      final barangay = BarangayService().matchFromLatLng(widget.userLocation!);

      if (mounted) {
        setState(() {
          _isInsideBarangay = barangay != null;
          _detectedBarangay = barangay?.name;
          _isCheckingBarangay = false;
        });

        if (barangay != null) {
          debugPrint('🟢 User is inside barangay: ${barangay.name}');
        } else {
          debugPrint('🔴 User is NOT inside any barangay polygon.');
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking barangay: $e');
      if (mounted) {
        setState(() {
          _isInsideBarangay = null;
          _detectedBarangay = null;
          _isCheckingBarangay = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(LocationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLocation != null &&
        widget.userLocation != oldWidget.userLocation) {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: widget.userLocation!, zoom: _locationZoom),
          ),
        );
      }
      // Re-check barangay when location updates
      if (_barangayPolylines.isNotEmpty) {
        _checkUserBarangay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final hasLocation = widget.userLocation != null;
    final addressText = widget.address != null
        ? formatAddress(widget.address)
        : (hasLocation ? 'Fetching address...' : 'Location not available.');

    // ✅ Determine if submit should be enabled
    // Enable if: has location AND (inside barangay OR still checking)
    // Disable if: no location OR explicitly outside barangay
    final canSubmit =
        hasLocation &&
        (_isInsideBarangay == true ||
            (_isInsideBarangay == null && !_isCheckingBarangay));

    // Prepare marker set
    Set<Marker> userMarkers = {};
    if (hasLocation && _userMarkerIcon != null) {
      userMarkers = {
        Marker(
          markerId: const MarkerId('user_location'),
          position: widget.userLocation!,
          icon: _userMarkerIcon!,
          anchor: const Offset(0.5, 1.0),
          infoWindow: InfoWindow(
            title: _detectedBarangay != null
                ? 'You are in $_detectedBarangay'
                : 'You are here',
          ),
        ),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your current location',
          style: TextStyle(
            fontSize: info.scaleFont(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: _isInsideBarangay == true ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addressText,
                      style: TextStyle(fontSize: info.scaleFont(14)),
                    ),
                    if (_detectedBarangay != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Barangay: $_detectedBarangay',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isCheckingBarangay)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh location',
                  onPressed: () {
                    widget.onRetryLocation();
                    // Reload barangay check after location refresh
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) _checkUserBarangay();
                    });
                  },
                ),
            ],
          ),
        ),
        // ✅ Show warning only when explicitly outside Valenzuela
        if (hasLocation && _isInsideBarangay == false && !_isCheckingBarangay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This service is only available in Valenzuela City. Please ensure your location is accurate and try refreshing.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: info.scaleFont(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // ✅ Show info when still checking
        if (_isCheckingBarangay)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verifying location...',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: info.scaleFont(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: hasLocation
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.userLocation!,
                    zoom: _locationZoom,
                  ),
                  markers: userMarkers,
                  polylines: _barangayPolylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: widget.userLocation!,
                          zoom: _locationZoom,
                        ),
                      ),
                    );
                  },
                  style: MapUtils.style,
                )
              : Center(
                  child: widget.isLocating
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Acquiring location & permissions...',
                              style: TextStyle(fontSize: info.scaleFont(14)),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: info.scale(64),
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to fetch location.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: info.scaleFont(16),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check permissions and try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: info.scaleFont(14),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: widget.onRetryLocation,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: !hasLocation
                    ? 'Location required'
                    : _isInsideBarangay == false
                    ? 'Must be in Valenzuela City'
                    : _isCheckingBarangay
                    ? 'Verifying location...'
                    : 'Submit your report',
                child: ElevatedButton(
                  onPressed: canSubmit ? widget.onSubmit : null,
                  child: _isCheckingBarangay
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Submit Report'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
