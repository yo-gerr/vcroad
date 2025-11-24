import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vcroad_v2/shared/models/report.dart';
import 'package:vcroad_v2/shared/models/advisory.dart'; // <-- add
import 'package:flutter/foundation.dart'; // for kIsWeb

class MarkerService {
  MarkerService._();
  static final instance = MarkerService._();

  // Replace single user marker with size-aware cache
  final Map<int, BitmapDescriptor> _userMarkerCache = {};

  // Asset for user location
  static const String _userAsset = 'assets/icons/user_marker.webp';

  BitmapDescriptor?
  _userMarker; // (legacy field kept if other code references it)

  // Cache: category+px -> descriptor (size-aware)
  final Map<String, BitmapDescriptor> _categoryIcons = {};

  // advisory id + px -> descriptor
  final Map<String, BitmapDescriptor> _advisoryIcons = {};

  // Helper to compute cache key for category icons
  String _categoryKey(ReportCategory cat, int px) => '${cat.index}_$px';
  // Helper to compute cache key for advisory icons
  String _advisoryKey(String id, int px) => '${id}_$px';

  // Centralized pixel sizing computation for logicalSize -> targetPx
  int _targetPxFor(
    BuildContext? context,
    double logicalSize, {
    int minPx = 20,
    int maxPx = 128,
  }) {
    // Platform-aware scaling:
    // - On web: increase marker logical size (CSS pixels) to make markers more
    //   visible on desktop/browser layouts, but avoid multiplying by DPR.
    // - On mobile/native: reduce logical size before applying DPR so markers
    //   are less visually dominant on small screens while keeping crispness.
    const double webScale = 1.35; // keep web larger for desktop visibility
    // Reduced mobileScale -> smaller rendered icons on phones while still
    // using DPR for sharpness. Tweak value (0.5..0.8) to taste.
    const double mobileScale = 0.65; // stronger reduction for mobile

    if (kIsWeb) {
      final webPx = (logicalSize * webScale).round();
      return math.max(minPx, math.min(maxPx, webPx));
    }

    final dpr = context != null
        ? MediaQuery.of(context).devicePixelRatio
        : ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final targetPx = (logicalSize * mobileScale * dpr).round();
    return math.max(minPx, math.min(maxPx, targetPx));
  }

  /// Synchronous accessor for cached category icon.
  BitmapDescriptor? getCachedCategoryIcon(ReportCategory cat) {
    // best-effort return any cached variant (prefer typical sizes)
    for (final e in _categoryIcons.entries) {
      if (e.key.startsWith('${cat.index}_')) return e.value;
    }
    return null;
  }

  /// Clear cached icons.
  void clearCache() {
    _userMarker = null;
    _userMarkerCache.clear();
    _categoryIcons.clear();
    _advisoryIcons.clear();
  }

  /// Backward compatible default user marker (no custom).
  Future<BitmapDescriptor> getUserMarker([ImageConfiguration? _]) async {
    if (_userMarker != null) return _userMarker!;
    _userMarker = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueAzure,
    );
    return _userMarker!;
  }

  /// New: get (or load) custom user marker at a logical size.
  Future<BitmapDescriptor> getCustomUserMarker(
    BuildContext context, {
    double logicalSize = 56.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);

    final cached = _userMarkerCache[targetPx];
    if (cached != null) return cached;

    try {
      final bd = await _loadAndResizeAsset(_userAsset, targetPx);
      _userMarkerCache[targetPx] = bd;
      return bd;
    } catch (_) {
      final fallback = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
      _userMarkerCache[targetPx] = fallback;
      return fallback;
    }
  }

  /// Preload and cache report category markers at a deterministic pixel size.
  Future<void> preloadCategoryMarkers(
    BuildContext context, {
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);

    final futures = <Future<void>>[];
    for (final cat in ReportCategory.values) {
      final key = _categoryKey(cat, targetPx);
      if (_categoryIcons.containsKey(key)) continue;
      futures.add(
        _loadAndResizeAsset(cat.asset, targetPx)
            .then((bd) {
              _categoryIcons[key] = bd;
            })
            .catchError((_) {
              _categoryIcons[key] = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              );
            }),
      );
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  /// Get category marker (loads lazily if not preloaded).
  Future<BitmapDescriptor> getCategoryMarker(
    ReportCategory cat, {
    BuildContext? context,
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);
    final key = _categoryKey(cat, targetPx);
    final cached = _categoryIcons[key];
    if (cached != null) return cached;

    try {
      final bd = await _loadAndResizeAsset(cat.asset, targetPx);
      _categoryIcons[key] = bd;
      return bd;
    } catch (_) {
      final def = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
      _categoryIcons[key] = def;
      return def;
    }
  }

  /// Build a marker using the category icon and correct anchor.
  /// Optional [onTap] will be wired to marker tap (useful to open details).
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
    final icon = await getCategoryMarker(
      category,
      context: context,
      logicalSize: logicalSize,
    );
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow.noText,
      anchor: const Offset(0.5, 1.0), // pin tip at point
      zIndexInt: 1,
      onTap: onTap,
    );
  }

  // Convert Material Color to Google hue (0..360).
  double _colorToHue(Color c) {
    final hsv = HSVColor.fromColor(c);
    return hsv.hue;
  }

  /// Preload and cache advisory category markers at a deterministic pixel size.
  Future<void> preloadAdvisoryMarkers(
    BuildContext context, {
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);

    final futures = <Future<void>>[];
    for (final cat in advisoryCategories) {
      final key = _advisoryKey(cat.id, targetPx);
      if (_advisoryIcons.containsKey(key)) continue;

      // Prefer custom asset if provided, else colored default marker.
      final hasAsset = cat.markerIconPath.isNotEmpty;
      futures.add(() async {
        try {
          if (hasAsset) {
            final bd = await _loadAndResizeAsset(cat.markerIconPath, targetPx);
            _advisoryIcons[key] = bd;
          } else {
            _advisoryIcons[key] = BitmapDescriptor.defaultMarkerWithHue(
              _colorToHue(cat.color),
            );
          }
        } catch (_) {
          _advisoryIcons[key] = BitmapDescriptor.defaultMarkerWithHue(
            _colorToHue(cat.color),
          );
        }
      }());
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  /// Get advisory category marker (loads lazily if not preloaded).
  Future<BitmapDescriptor> getAdvisoryMarkerIcon(
    AdvisoryCategory category, {
    BuildContext? context,
    double logicalSize = 48.0,
  }) async {
    final targetPx = _targetPxFor(context, logicalSize, minPx: 20, maxPx: 128);
    final key = _advisoryKey(category.id, targetPx);
    final cached = _advisoryIcons[key];
    if (cached != null) return cached;

    try {
      if (category.markerIconPath.isNotEmpty) {
        final bd = await _loadAndResizeAsset(category.markerIconPath, targetPx);
        _advisoryIcons[key] = bd;
        return bd;
      }
      final def = BitmapDescriptor.defaultMarkerWithHue(
        _colorToHue(category.color),
      );
      _advisoryIcons[key] = def;
      return def;
    } catch (_) {
      final def = BitmapDescriptor.defaultMarkerWithHue(
        _colorToHue(category.color),
      );
      _advisoryIcons[key] = def;
      return def;
    }
  }

  /// Build an advisory marker with proper icon and anchor.
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
    final icon = await getAdvisoryMarkerIcon(
      category,
      context: context,
      logicalSize: logicalSize,
    );
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow.noText,
      anchor: const Offset(0.5, 1.0),
      zIndexInt: 2,
      onTap: onTap,
    );
  }

  /// Deterministic decode + resize for predictable size across platforms.
  Future<BitmapDescriptor> _loadAndResizeAsset(
    String assetPath,
    int targetWidthPx,
  ) async {
    // Web: prefer platform implementation that integrates with the plugin.
    // BitmapDescriptor.fromAssetImage works reliably on web and returns a valid
    // BitmapDescriptor that the web plugin understands.
    if (kIsWeb) {
      try {
        // Provide an ImageConfiguration with a size to guide asset resolution on web.
        // Use logical pixels so web rendering doesn't scale by devicePixelRatio.
        final cfg = ImageConfiguration(
          size: Size(targetWidthPx.toDouble(), targetWidthPx.toDouble()),
          devicePixelRatio: 1.0,
        );
        return await BitmapDescriptor.asset(cfg, assetPath);
      } catch (e) {
        debugPrint(
          '[MarkerService][_loadAndResizeAsset] web asset() failed: $e',
        );
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }
    }

    // Native/mobile: decode & resize via image codec to control pixel size.
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidthPx,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('encode failed');
      return BitmapDescriptor.bytes(png.buffer.asUint8List());
    } catch (e, st) {
      debugPrint(
        '[MarkerService][_loadAndResizeAsset] native decode failed: $e\n$st',
      );
      // Conservative fallback to default marker for reliability
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  /// Get a fully-built Marker for a ReportData (async, loads & caches icon).
  Future<Marker> getReportMarkerFor({
    required String id,
    required LatLng position,
    required ReportCategory category,
    String? title,
    String? snippet,
    BuildContext? context,
    double logicalSize = 48.0,
  }) async {
    // Reuse existing async loader that returns a BitmapDescriptor then create Marker
    final icon = await getCategoryMarker(
      category,
      context: context,
      logicalSize: logicalSize,
    );
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow.noText,
      anchor: const Offset(0.5, 1.0),
      zIndexInt: 1,
    );
  }

  /// Synchronous builder using cached icon (fast fallback). If category icon not cached,
  /// returns a default hue-based marker to avoid async wait in UI.
  Marker buildReportMarkerFromCache({
    required String id,
    required LatLng position,
    required ReportCategory category,
    String? title,
    String? snippet,
    BitmapDescriptor? overrideIcon,
  }) {
    final icon =
        overrideIcon ??
        // use helper to find any cached icon variant
        getCachedCategoryIcon(category) ??
        defaultMarkerForCategory(category);
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon,
      infoWindow: InfoWindow.noText,
      anchor: const Offset(0.5, 1.0),
    );
  }

  BitmapDescriptor defaultMarkerForCategory(ReportCategory category) {
    switch (category) {
      case ReportCategory.roadFlooding:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case ReportCategory.roadAccident:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case ReportCategory.roadObstruction:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case ReportCategory.outdatedPosters:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
      case ReportCategory.roadConstruction:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      case ReportCategory.brokenSignage:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }
}
