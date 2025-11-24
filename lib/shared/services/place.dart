import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  const PlaceSuggestion({required this.placeId, required this.description});
}

class PlaceDetails {
  final String name;
  final String address;
  final LatLng? location;
  final LatLngBounds? viewport;
  const PlaceDetails({
    required this.name,
    required this.address,
    required this.location,
    required this.viewport,
  });
}

class PlaceService {
  PlaceService._();
  static final instance = PlaceService._();

  final String _baseUrl =
      'https://us-central1-vcroad-a0022.cloudfunctions.net/vcroadApi/places';

  Future<LatLng?> getCurrentUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    Position position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  /// Reverse geocode: lat,lng -> address
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/geocode?latlng=$latitude,$longitude'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        return results[0]['formatted_address'] ?? 'Unknown location';
      }
    }
    return 'Unknown location';
  }

  /// Returns a stream of Position if permission is granted.
  /// If permission is denied, the stream completes immediately.
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 5, // meters
  }) async* {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // no permission -> yield nothing (empty stream)
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
    final uri = Uri.parse('$_baseUrl/autocomplete').replace(
      queryParameters: {
        'input': input,
        if (sessionToken != null) 'sessiontoken': sessionToken,
      },
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final preds = (data['predictions'] as List?) ?? const [];
      return preds
          .map((p) {
            return PlaceSuggestion(
              placeId: p['place_id'] as String,
              description: p['description'] as String? ?? '',
            );
          })
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) debugPrint('autocomplete error: $e');
      return const [];
    }
  }

  Future<PlaceDetails?> placeDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/details').replace(
      queryParameters: {
        'place_id': placeId,
        if (sessionToken != null) 'sessiontoken': sessionToken,
      },
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        debugPrint('❌ placeDetails HTTP ${res.statusCode}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        debugPrint('❌ placeDetails: no result in response');
        return null;
      }

      LatLng? loc;
      LatLngBounds? vp;

      final geometry = result['geometry'] as Map<String, dynamic>?;
      if (geometry != null) {
        final location = geometry['location'] as Map<String, dynamic>?;
        if (location != null) {
          final lat = (location['lat'] as num?)?.toDouble();
          final lng = (location['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            loc = LatLng(lat, lng);
          }
        }
        final viewport = geometry['viewport'] as Map<String, dynamic>?;
        if (viewport != null) {
          final ne = viewport['northeast'] as Map<String, dynamic>?;
          final sw = viewport['southwest'] as Map<String, dynamic>?;
          if (ne != null && sw != null) {
            final nelat = (ne['lat'] as num?)?.toDouble();
            final nelng = (ne['lng'] as num?)?.toDouble();
            final swlat = (sw['lat'] as num?)?.toDouble();
            final swlng = (sw['lng'] as num?)?.toDouble();
            if (nelat != null &&
                nelng != null &&
                swlat != null &&
                swlng != null) {
              vp = LatLngBounds(
                northeast: LatLng(nelat, nelng),
                southwest: LatLng(swlat, swlng),
              );
            }
          }
        }
      }

      if (loc == null && vp == null) {
        debugPrint('⚠️ placeDetails: no geometry found for $placeId');
      }

      return PlaceDetails(
        name: (result['name'] as String?) ?? '',
        address: (result['formatted_address'] as String?) ?? '',
        location: loc,
        viewport: vp,
      );
    } catch (e, st) {
      debugPrint('❌ placeDetails error: $e\n$st');
      return null;
    }
  }
}
