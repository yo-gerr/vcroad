import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vcroad_v2/shared/utils/map/map.dart';
import 'package:vcroad_v2/shared/utils/map/interaction_controller.dart';
import 'package:vcroad_v2/shared/utils/map/map_controls.dart'; // conditional export

class MapView extends StatelessWidget {
  final int mapRecreateId;
  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final bool myLocationEnabled;
  final bool trafficEnabled;
  final bool gesturesEnabled;
  final Function(GoogleMapController) onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final Function(LatLng)? onTap;

  const MapView({
    super.key,
    required this.mapRecreateId,
    required this.initialCameraPosition,
    required this.markers,
    required this.myLocationEnabled,
    required this.trafficEnabled,
    required this.gesturesEnabled,
    required this.onMapCreated,
    this.onCameraMoveStarted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MapInteractionController.instance.enabled,
      builder: (context, interactionsEnabled, child) {
        final effectiveGestures = gesturesEnabled && interactionsEnabled;
        return GoogleMap(
          key: ValueKey<int>(mapRecreateId),
          initialCameraPosition: initialCameraPosition,
          markers: markers,
          myLocationEnabled: myLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          trafficEnabled: trafficEnabled,
          scrollGesturesEnabled: effectiveGestures,
          zoomGesturesEnabled: effectiveGestures,
          rotateGesturesEnabled: effectiveGestures,
          tiltGesturesEnabled: effectiveGestures,
          onMapCreated: (controller) {
            onMapCreated(controller);
            // run hide only for web (helper is a no-op on other platforms)
            if (kIsWeb) {
              hideMapControlsWeb(); // conditional export will call web impl on web
            }
          },
          onCameraMoveStarted: onCameraMoveStarted,
          onTap: onTap,
          style: MapUtils.style,
        );
      },
    );
  }
}
