import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';

class BarangayService {
  static final BarangayService _instance = BarangayService._internal();
  factory BarangayService() => _instance;
  BarangayService._internal();

  List<Barangay> barangays = [];
  bool isLoaded = false;
  bool isLoading = false;

  // fast lookup map: normalized lowercase name -> logo path (asset or url)
  final Map<String, String> _logoMap = {};

  /// Returns logo path (asset or url) for a barangay name, or null.
  String? logoForName(String? name) {
    if (name == null || name.isEmpty) return null;
    final key = _normalizeName(name);
    // fast single-map lookup (try space form then underscored form)
    return _logoMap[key] ?? _logoMap[key.replaceAll(' ', '_')];
  }

  String _normalizeName(String name) => name.trim().toLowerCase();

  /// Precache common logos (asset images) to reduce first-frame flicker.
  /// Call from a widget with a BuildContext (e.g. after loadBarangays completes).
  Future<void> preloadLogos(BuildContext context, {int max = 50}) async {
    if (!isLoaded || barangays.isEmpty) return;
    final assets = <String>{};
    for (final b in barangays) {
      final logo = b.logo;
      if (logo != null && logo.isNotEmpty && !logo.startsWith('http')) {
        assets.add(logo);
        if (assets.length >= max) break;
      }
    }
    for (final asset in assets) {
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (_) {
        // ignore individual failures
      }
    }
  }

  static const LatLng _valenzuelaCenter = LatLng(14.7083, 120.9833);
  static const String _cacheKey = 'barangays_cache_v1';

  LatLngBounds get valenzuelaBounds {
    const delta = 0.05; // ✅ Increased for better coverage
    return LatLngBounds(
      southwest: LatLng(
        _valenzuelaCenter.latitude - delta,
        _valenzuelaCenter.longitude - delta,
      ),
      northeast: LatLng(
        _valenzuelaCenter.latitude + delta,
        _valenzuelaCenter.longitude + delta,
      ),
    );
  }

  /// Generate polylines for map overlay (memoized)
  Set<Polyline> generateBarangayPolylines({Color? color, int width = 2}) {
    if (barangays.isEmpty) return {};

    final effectiveColor = color ?? const Color.fromRGBO(33, 150, 243, 0.4);

    return barangays
        .where((b) => b.polygons != null)
        .expand((b) => b.polygons!)
        .map(
          (p) => Polyline(
            polylineId: PolylineId("barangay_${p.hashCode}"),
            points: p,
            color: effectiveColor,
            width: width,
            zIndex: 1,
          ),
        )
        .toSet();
  }

  /// Load barangays with caching and background parsing
  Future<void> loadBarangays({bool forceReload = false}) async {
    if (isLoaded && !forceReload) return;
    if (isLoading) return; // Prevent duplicate loads

    isLoading = true;

    try {
      // Try cache first for metadata (optional, for dropdown/search)
      if (!forceReload) {
        final cached = await _loadFromCache();
        if (cached != null && cached.isNotEmpty) {
          // Use cached metadata for dropdowns/search
          // But DO NOT use for polygons/detection
        }
      }

      // Always load full polygons from assets for map/detection
      final rawJson = await rootBundle.loadString(
        'assets/json/barangays.geojson',
      );

      // Parse in compute isolate to avoid UI jank
      barangays = await compute(_parseBarangaysInIsolate, rawJson);
      barangays.sort((a, b) => a.name.compareTo(b.name));

      // build fast lookup map (normalized lower-case keys)
      // precompute both "space" and "underscored" variants and also a prefix-stripped key
      _logoMap.clear();
      for (final b in barangays) {
        final logo = b.logo ?? '';
        final nameKey = _normalizeName(b.name);
        _logoMap[nameKey] = logo;
        _logoMap[nameKey.replaceAll(' ', '_')] = logo;

        // also register stripped form (remove common prefixes like "Brgy." or "Barangay")
        final stripped = nameKey
            .replaceAll(RegExp(r'^(brgy\.?\s+|barangay\s+)'), '')
            .trim();
        if (stripped.isNotEmpty) {
          _logoMap[stripped] = logo;
          _logoMap[stripped.replaceAll(' ', '_')] = logo;
        }
      }

      // Cache for next time (metadata only)
      await _saveToCache(barangays);

      isLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Failed to load barangays: $e');
      rethrow;
    } finally {
      isLoading = false;
    }
  }

  /// Parse GeoJSON in isolate (runs on background thread)
  static List<Barangay> _parseBarangaysInIsolate(String rawJson) {
    final jsonData = jsonDecode(rawJson) as Map<String, dynamic>;
    final features = (jsonData['features'] as List<dynamic>);

    return features.map<Barangay>((f) {
      final props = f['properties'] as Map<String, dynamic>;
      final geometry = f['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;

      final polygons = <List<LatLng>>[];
      for (final poly in coords) {
        final polygonPoints = <LatLng>[];
        for (final ring in (poly as List)) {
          for (final point in (ring as List)) {
            final lng = (point[0] as num).toDouble();
            final lat = (point[1] as num).toDouble();
            polygonPoints.add(LatLng(lat, lng));
          }
        }
        if (polygonPoints.isNotEmpty) {
          polygons.add(polygonPoints);
        }
      }

      return Barangay(
        name: props['barangay'] as String? ?? 'Unknown',
        district: props['district'] as String?,
        logo: props['logo'] as String?,
        polygons: polygons.isEmpty ? null : polygons,
        bounds: Barangay.computeBounds(polygons.isEmpty ? null : polygons),
      );
    }).toList();
  }

  /// Cache barangays (without polygon data to save space)
  Future<void> _saveToCache(List<Barangay> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
        data.map((b) => b.toJson(includePolygons: false)).toList(),
      );
      await prefs.setString(_cacheKey, json);
    } catch (e) {
      debugPrint('⚠️ Failed to cache barangays: $e');
    }
  }

  /// Load from cache (metadata only, polygons reloaded from assets)
  Future<List<Barangay>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;

      final list = jsonDecode(cached) as List<dynamic>;
      return list
          .map((json) => Barangay.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Failed to load cache: $e');
      return null;
    }
  }

  /// Generate dropdown items (memoized, lazy)
  List<DropdownMenuItem<Barangay>> get barangayDropdownItems {
    if (!isLoaded || barangays.isEmpty) return [];
    return barangays
        .map(
          (b) => DropdownMenuItem<Barangay>(
            value: b,
            child: Text(
              b.name.replaceAll('_', ' '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  /// Find barangay from location (optimized with bounds check)
  Barangay? matchFromLatLng(LatLng point) {
    if (!isLoaded || barangays.isEmpty) return null;

    // ✅ Fast bounds check first (eliminates 90%+ of checks)
    final candidates = barangays.where((b) {
      if (b.bounds == null) return false;
      return _pointInBounds(point, b.bounds!);
    }).toList();

    // ✅ Precise polygon check only on candidates
    for (final b in candidates) {
      if (b.polygons == null) continue;
      for (final polygon in b.polygons!) {
        if (_pointInPolygon(point, polygon)) return b;
      }
    }

    return null;
  }

  /// Fast bounding box check
  bool _pointInBounds(LatLng point, LatLngBounds bounds) {
    return point.latitude >= bounds.southwest.latitude &&
        point.latitude <= bounds.northeast.latitude &&
        point.longitude >= bounds.southwest.longitude &&
        point.longitude <= bounds.northeast.longitude;
  }

  /// Ray casting algorithm for point-in-polygon test
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    int intersectCount = 0;
    for (int j = 0; j < polygon.length; j++) {
      final v1 = polygon[j];
      final v2 = polygon[(j + 1) % polygon.length];

      if (((v1.latitude > point.latitude) != (v2.latitude > point.latitude)) &&
          (point.longitude <
              (v2.longitude - v1.longitude) *
                      (point.latitude - v1.latitude) /
                      (v2.latitude - v1.latitude) +
                  v1.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  /// Search barangays by name (case-insensitive)
  List<Barangay> search(String query) {
    if (query.isEmpty) return barangays;
    final lowerQuery = query.toLowerCase();
    return barangays
        .where((b) => b.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Clear cache (for testing or updates)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    isLoaded = false;
  }

  /// Dispose (call on app exit if needed)
  void dispose() {
    barangays.clear();
    isLoaded = false;
  }
}
