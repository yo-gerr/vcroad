import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Barangay {
  final String name;
  final String? district;
  final String? logo;
  final List<List<LatLng>>? polygons;
  final LatLngBounds? bounds; // ✅ Add precomputed bounds for fast hit testing

  const Barangay({
    required this.name,
    this.district,
    this.logo,
    this.polygons,
    this.bounds,
  });

  /// Compute bounding box from polygons (call once during load)
  static LatLngBounds? computeBounds(List<List<LatLng>>? polygons) {
    if (polygons == null || polygons.isEmpty) return null;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final polygon in polygons) {
      for (final point in polygon) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
    }

    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  Map<String, dynamic> toJson({bool includePolygons = false}) {
    return {
      'name': name,
      if (district != null) 'district': district,
      if (logo != null) 'logo': logo,
      if (includePolygons && polygons != null)
        'polygons': polygons!
            .map((poly) => poly.map((p) => [p.latitude, p.longitude]).toList())
            .toList(),
    };
  }

  factory Barangay.fromJson(Map<String, dynamic> json) {
    List<List<LatLng>>? polygons;
    if (json['polygons'] != null) {
      polygons = (json['polygons'] as List)
          .map<List<LatLng>>(
            (poly) => (poly as List)
                .map<LatLng>((p) => LatLng(p[0] as double, p[1] as double))
                .toList(),
          )
          .toList();
    }

    return Barangay(
      name: json['name'] as String,
      district: json['district'] as String?,
      logo: json['logo'] as String?, // Already nullable, ensure it's safe
      polygons: polygons,
      bounds: computeBounds(polygons),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Barangay &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Barangay($name)';
}
