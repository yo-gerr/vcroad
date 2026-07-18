import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:vcroad/data/repositories/permission.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  final LatLng? location;
  final LatLngBounds? viewport;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    this.location,
    this.viewport,
  });

  factory PlaceSuggestion.fromNominatim(Map<String, dynamic> json) {
    final osmType = _osmTypeCode(json['osm_type'] as String? ?? '');
    final osmId = json['osm_id'];
    final placeId = '$osmType$osmId';
    final description = json['display_name'] as String? ?? '';

    return PlaceSuggestion(
      placeId: placeId,
      description: description,
      location: _parseLatLng(json),
      viewport: _parseBoundingBox(json),
    );
  }
}

class PlaceDetails {
  final String name;
  final String address;
  final LatLng? location;
  final LatLngBounds? viewport;
  const PlaceDetails({
    required this.name,
    required this.address,
    this.location,
    this.viewport,
  });
}

class PlaceService {
  PlaceService._();
  static final instance = PlaceService._();

  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'VCRoad/2.0 (Flutter; +https://vcroad.app)';

  final Map<String, PlaceDetails> _detailsCache = {};

  Future<LatLng?> getCurrentUserLocation() async {
    final statuses = await PermissionService.instance.requestLocation();
    if (!PermissionService.instance.allGranted(statuses)) {
      return null;
    }
    Position position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse('$_nominatimBase/reverse').replace(
      queryParameters: {
        'lat': latitude.toStringAsFixed(6),
        'lon': longitude.toStringAsFixed(6),
        'format': 'jsonv2',
        'addressdetails': '1',
      },
    );
    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['display_name'] as String? ?? 'Unknown location';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Nominatim reverse error: $e');
    }
    return 'Unknown location';
  }

  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 5,
  }) async* {
    final statuses = await PermissionService.instance.requestLocation();
    if (!PermissionService.instance.allGranted(statuses)) {
      return;
    }
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
    yield* Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? sessionToken,
  }) async {
    if (input.trim().isEmpty) return const [];
    final uri = Uri.parse('$_nominatimBase/search').replace(
      queryParameters: {
        'q': input,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
      },
    );
    try {
      final res = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as List;
      return data.map((item) {
        final map = item as Map<String, dynamic>;
        final s = PlaceSuggestion.fromNominatim(map);
        _detailsCache[s.placeId] = PlaceDetails(
          name: s.description.split(',').first.trim(),
          address: s.description,
          location: s.location,
          viewport: s.viewport,
        );
        return s;
      }).toList(growable: false);
    } catch (e) {
      if (kDebugMode) debugPrint('Nominatim search error: $e');
      return const [];
    }
  }

  Future<PlaceDetails?> placeDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    final cached = _detailsCache[placeId];
    if (cached != null) return cached;

    try {
      final match = RegExp(r'^([NWR])(\d+)$').firstMatch(placeId);
      if (match == null) return null;

      final osmType = match.group(1)!;
      final osmId = match.group(2)!;
      final uri = Uri.parse('$_nominatimBase/lookup').replace(
        queryParameters: {
          'osm_ids': '$osmType$osmId',
          'format': 'jsonv2',
        },
      );
      final res = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return null;

      final result = data[0] as Map<String, dynamic>;
      final displayName = result['display_name'] as String? ?? '';
      return PlaceDetails(
        name: displayName.isNotEmpty ? displayName.split(',').first.trim() : '',
        address: displayName,
        location: _parseLatLng(result),
        viewport: _parseBoundingBox(result),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Nominatim lookup error: $e');
      return null;
    }
  }

}

String _osmTypeCode(String type) {
  switch (type.toLowerCase()) {
    case 'node':
      return 'N';
    case 'way':
      return 'W';
    case 'relation':
      return 'R';
    default:
      return type.toUpperCase();
  }
}

LatLng? _parseLatLng(Map<String, dynamic> json) {
  final lat = (json['lat'] as String?) ?? (json['lat'] as num?)?.toString();
  final lon = (json['lon'] as String?) ?? (json['lon'] as num?)?.toString();
  if (lat != null && lon != null) {
    final latD = double.tryParse(lat);
    final lonD = double.tryParse(lon);
    if (latD != null && lonD != null) return LatLng(latD, lonD);
  }
  return null;
}

LatLngBounds? _parseBoundingBox(Map<String, dynamic> json) {
  final bbox = json['boundingbox'] as List?;
  if (bbox != null && bbox.length == 4) {
    final south = double.tryParse(bbox[0].toString());
    final north = double.tryParse(bbox[1].toString());
    final west = double.tryParse(bbox[2].toString());
    final east = double.tryParse(bbox[3].toString());
    if (south != null && north != null && west != null && east != null) {
      return LatLngBounds(LatLng(south, west), LatLng(north, east));
    }
  }
  return null;
}
