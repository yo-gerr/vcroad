import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vcroad_v2/shared/services/place.dart';
import 'package:vcroad_v2/shared/services/permission.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';

class LocationProvider extends ChangeNotifier {
  LatLng? location;
  String? address;
  bool isLocating = false;

  // Barangay info
  bool? isInsideBarangay; // null = unknown
  String? barangayName;
  Set<Polyline> barangayPolylines = {};

  StreamSubscription<Position>? _posSub;

  // Start location flow: permission -> current location -> address -> subscribe
  Future<void> start({bool force = false}) async {
    if (isLocating && !force) return;
    isLocating = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        isLocating = false;
        notifyListeners();
        return;
      }

      final statuses = await PermissionService.instance.guardedRequest({
        AppPermission.location,
      });

      if (!PermissionService.instance.allGranted(statuses)) {
        isLocating = false;
        notifyListeners();
        return;
      }

      // Do not block initial location acquisition on loading barangay geometry.
      // Load barangays in background to avoid delaying time-to-first-location.
      if (!BarangayService().isLoaded) {
        unawaited(
          BarangayService()
              .loadBarangays()
              .then((_) {
                // generate polylines when loaded (non-blocking)
                barangayPolylines = BarangayService().generateBarangayPolylines(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                  width: 3,
                );
                notifyListeners();
              })
              .catchError((e) {
                if (kDebugMode) {
                  debugPrint('[LocationProvider] loadBarangays error: $e');
                }
              }),
        );
      } else {
        barangayPolylines = BarangayService().generateBarangayPolylines(
          color: const Color(0xFF2196F3).withValues(alpha: 0.4),
          width: 3,
        );
      }

      // Initial location: prefer platform last-known (non-web), else use PlaceService fallback.
      Position? lastPos;
      if (!kIsWeb) {
        try {
          lastPos = await Geolocator.getLastKnownPosition();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[LocationProvider] getLastKnownPosition error: $e');
          }
        }
      }

      if (lastPos != null) {
        location = LatLng(lastPos.latitude, lastPos.longitude);
      } else {
        // PlaceService should handle platform-specific geolocation (web/mobile)
        final loc = await PlaceService.instance.getCurrentUserLocation();
        if (loc != null) {
          location = LatLng(loc.latitude, loc.longitude);
        }
      }

      // If we already obtained a usable location, mark locating done and notify now
      if (location != null && isLocating) {
        isLocating = false;
        notifyListeners();
      }

      if (location != null) {
        // Resolve address asynchronously (do not block UI longer than needed)
        address = await PlaceService.instance.getAddressFromCoordinates(
          location!.latitude,
          location!.longitude,
        );
        final b = BarangayService().matchFromLatLng(location!);
        isInsideBarangay = b != null;
        barangayName = b?.name;
      }

      // start streaming updates (debounced by PlaceService)
      await _startStream();
    } catch (e) {
      if (kDebugMode) debugPrint('[LocationProvider] start error: $e');
    } finally {
      isLocating = false;
      notifyListeners();
    }
  }

  Future<void> _startStream() async {
    await _posSub?.cancel();
    _posSub = PlaceService.instance
        .getPositionStream(accuracy: LocationAccuracy.best, distanceFilter: 5)
        .listen(
          (pos) async {
            final next = LatLng(pos.latitude, pos.longitude);
            // skip tiny moves
            if (location != null) {
              final dist = Geolocator.distanceBetween(
                location!.latitude,
                location!.longitude,
                next.latitude,
                next.longitude,
              );
              if (dist < 2.5) return;
            }

            location = next;
            final b = BarangayService().matchFromLatLng(next);
            isInsideBarangay = b != null;
            barangayName = b?.name;
            // optionally refresh address less frequently; do async but don't await to avoid UI blocking
            unawaited(
              PlaceService.instance
                  .getAddressFromCoordinates(next.latitude, next.longitude)
                  .then((a) {
                    address = a;
                    notifyListeners();
                  })
                  .catchError((_) {}),
            );
            notifyListeners();
          },
          onError: (e) {
            if (kDebugMode) debugPrint('[LocationProvider] stream error: $e');
          },
        );
  }

  Future<void> refresh() async => start(force: true);

  Future<void> stop() async {
    await _posSub?.cancel();
    _posSub = null;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }
}
