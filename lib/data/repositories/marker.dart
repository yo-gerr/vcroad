import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:flutter/foundation.dart';

class MarkerService {
  MarkerService._();
  static final instance = MarkerService._();

  static const String _userAsset = 'assets/icons/user_marker.webp';

  final Map<int, ui.Image?> _userImageCache = {};
  final Map<String, ui.Image?> _categoryImageCache = {};
  final Map<String, ui.Image?> _advisoryImageCache = {};
  void clearCache() {
    _userImageCache.clear();
    _categoryImageCache.clear();
    _advisoryImageCache.clear();
  }

  int _targetPxFor(
    BuildContext? context,
    double logicalSize, {
    int minPx = 20,
    int maxPx = 128,
  }) {
    const double webScale = 1.35;
    const double mobileScale = 0.65;
    if (kIsWeb) {
      return math.max(minPx, math.min(maxPx, (logicalSize * webScale).round()));
    }
    final dpr = context != null
        ? MediaQuery.of(context).devicePixelRatio
        : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    return math.max(minPx, math.min(maxPx, (logicalSize * mobileScale * dpr).round()));
  }

  Future<ui.Image?> _loadImage(String assetPath, int targetWidthPx) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: targetWidthPx,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Widget _markerIconFromImage(ui.Image? image, {double size = 48}) {
    if (image == null) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.location_on, color: Colors.white, size: 24),
      );
    }
    return RawImage(
      image: image,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Future<Widget> getUserMarkerWidget(BuildContext context, {double logicalSize = 56.0}) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);
    final cached = _userImageCache[targetPx];
    if (cached != null) return _markerIconFromImage(cached, size: logicalSize);

    final image = await _loadImage(_userAsset, targetPx);
    _userImageCache[targetPx] = image;
    return _markerIconFromImage(image, size: logicalSize);
  }

  Future<Widget> getCategoryMarkerWidget(
    ReportCategory cat, {
    BuildContext? context,
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);
    final key = '${cat.index}_$targetPx';
    final cached = _categoryImageCache[key];
    if (cached != null) return _markerIconFromImage(cached, size: logicalSize);

    final image = await _loadImage(cat.asset, targetPx);
    _categoryImageCache[key] = image;
    return _markerIconFromImage(image, size: logicalSize);
  }

  Future<Widget> getAdvisoryMarkerWidget(
    AdvisoryCategory category, {
    BuildContext? context,
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);
    final key = '${category.id}_$targetPx';
    final cached = _advisoryImageCache[key];
    if (cached != null) return _markerIconFromImage(cached, size: logicalSize);

    if (category.markerIconPath.isNotEmpty) {
      final image = await _loadImage(category.markerIconPath, targetPx);
      _advisoryImageCache[key] = image;
      return _markerIconFromImage(image, size: logicalSize);
    }
    return Container(
      width: logicalSize,
      height: logicalSize,
      decoration: BoxDecoration(
        color: category.color,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.warning, color: Colors.white, size: 24),
    );
  }

  Widget _buildFallbackMarkerIcon(ReportCategory category, {double size = 48}) {
    Color color;
    switch (category) {
      case ReportCategory.roadFlooding: color = Colors.red; break;
      case ReportCategory.roadAccident: color = Colors.orange; break;
      case ReportCategory.roadObstruction: color = Colors.yellow; break;
      case ReportCategory.outdatedPosters: color = Colors.purple; break;
      case ReportCategory.roadConstruction: color = Colors.blue; break;
      case ReportCategory.brokenSignage: color = Colors.green; break;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: const Icon(Icons.location_on, color: Colors.white, size: 20),
    );
  }

  Future<Marker> buildReportMarkerAsync({
    required String id,
    required LatLng position,
    required ReportCategory category,
    required String title,
    String? snippet,
    BuildContext? context,
    double logicalSize = 48.0,
    VoidCallback? onTap,
  }) async {
    final widget = await getCategoryMarkerWidget(category, context: context, logicalSize: logicalSize);
    return Marker(
      point: position,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(width: logicalSize, height: logicalSize, child: widget),
      ),
    );
  }

  Future<Marker> buildAdvisoryMarkerAsync({
    required String id,
    required LatLng position,
    required AdvisoryCategory category,
    required String title,
    String? snippet,
    BuildContext? context,
    double logicalSize = 48.0,
    VoidCallback? onTap,
  }) async {
    final widget = await getAdvisoryMarkerWidget(category, context: context, logicalSize: logicalSize);
    return Marker(
      point: position,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(width: logicalSize, height: logicalSize, child: widget),
      ),
    );
  }

  Future<Marker> getReportMarkerFor({
    required String id,
    required LatLng position,
    required ReportCategory category,
    String? title,
    String? snippet,
    BuildContext? context,
    double logicalSize = 48.0,
  }) async {
    return buildReportMarkerAsync(
      id: id,
      position: position,
      category: category,
      title: title ?? '',
      snippet: snippet,
      context: context,
      logicalSize: logicalSize,
    );
  }

  Marker buildReportMarkerFromCache({
    required String id,
    required LatLng position,
    required ReportCategory category,
    String? title,
    String? snippet,
    Widget? overrideIcon,
  }) {
    return Marker(
      point: position,
      child: GestureDetector(
        child: SizedBox(
          width: 48,
          height: 48,
          child: overrideIcon ?? _buildFallbackMarkerIcon(category),
        ),
      ),
    );
  }

  Future<void> preloadCategoryMarkers(
    BuildContext context, {
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);
    await Future.wait(ReportCategory.values.map((cat) async {
      final key = '${cat.index}_$targetPx';
      if (!_categoryImageCache.containsKey(key)) {
        _categoryImageCache[key] = await _loadImage(cat.asset, targetPx);
      }
    }));
  }

  Future<void> preloadAdvisoryMarkers(
    BuildContext context, {
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);
    await Future.wait(advisoryCategories.map((cat) async {
      final key = '${cat.id}_$targetPx';
      if (!_advisoryImageCache.containsKey(key) && cat.markerIconPath.isNotEmpty) {
        _advisoryImageCache[key] = await _loadImage(cat.markerIconPath, targetPx);
      }
    }));
  }

  Future<Widget> getCustomUserMarker(BuildContext context, {double logicalSize = 56.0}) async {
    return getUserMarkerWidget(context, logicalSize: logicalSize);
  }
}
