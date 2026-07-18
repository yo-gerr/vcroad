import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vcroad/core/utils/map/map.dart';
import 'package:vcroad/core/utils/map/interaction_controller.dart';
import 'package:vcroad/core/utils/map/map_controls.dart';

class MapView extends StatefulWidget {
  final int mapRecreateId;
  final MapCamera initialCameraPosition;
  final List<Marker> markers;
  final bool gesturesEnabled;
  final Function(MapController) onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final void Function(LatLng)? onTap;

  const MapView({
    super.key,
    required this.mapRecreateId,
    required this.initialCameraPosition,
    required this.markers,
    required this.gesturesEnabled,
    required this.onMapCreated,
    this.onCameraMoveStarted,
    this.onTap,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final MapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MapInteractionController.instance.enabled,
      builder: (context, interactionsEnabled, child) {
        final effectiveGestures = widget.gesturesEnabled && interactionsEnabled;
        return FlutterMap(
          key: ValueKey<int>(widget.mapRecreateId),
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.initialCameraPosition.center,
            initialZoom: widget.initialCameraPosition.zoom,
            interactionOptions: effectiveGestures
                ? const InteractionOptions(flags: InteractiveFlag.all)
                : const InteractionOptions(flags: InteractiveFlag.none),
            onMapReady: () {
              widget.onMapCreated(_controller);
              if (kIsWeb) {
                hideMapControlsWeb();
              }
            },
            onMapEvent: (event) {
              if (event is MapEventMoveStart) {
                widget.onCameraMoveStarted?.call();
              }
            },
            onTap: (tapPosition, point) {
              widget.onTap?.call(point);
            },
          ),
          children: [
            MapUtils.tileLayer,
            MarkerLayer(markers: widget.markers, rotate: true),
          ],
        );
      },
    );
  }
}
