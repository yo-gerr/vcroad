import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vcroad_v2/shared/services/marker.dart';
import 'package:vcroad_v2/shared/models/report.dart';
import 'package:vcroad_v2/shared/models/advisory.dart';

/// Encapsulates MarkerService usage and caches results to avoid repeated I/O.
class MarkerManager {
  bool _preloaded = false;
  BitmapDescriptor? _userIcon;
  final Map<String, Marker> _reportMarkerCache = {};

  // Advisory caches
  final Map<String, Marker> _advisoryMarkerCache = {};
  final Map<String, String> _advisoryMarkerMeta = {}; // id -> hash meta

  // Helper: safely convert a dynamic / FutureOr result into a Marker or null.
  // This guards against platform JS interop objects (LegacyJavaScriptObject)
  // leaking into Dart typed lists and causing Future.wait type errors.
  Future<Marker?> _toMarkerSafe(dynamic maybe, {String? context}) async {
    try {
      // If already a Marker, return it immediately.
      if (maybe is Marker) return maybe;

      // If it's a Future, await it and validate result.
      if (maybe is Future) {
        final res = await maybe;
        if (res is Marker) return res;
        debugPrint(
          '[MarkerManager] Invalid marker result${context != null ? ' ($context)' : ''}: ${res.runtimeType}',
        );
        return null;
      }

      // Not a Marker nor a Future -> invalid
      debugPrint(
        '[MarkerManager] Ignoring non-marker value${context != null ? ' ($context)' : ''}: ${maybe.runtimeType}',
      );
      return null;
    } catch (e, st) {
      debugPrint(
        '[MarkerManager] Error converting to Marker${context != null ? ' ($context)' : ''}: $e\n$st',
      );
      return null;
    }
  }

  /// Preload category icons and (optionally) the user marker.
  Future<void> preload(
    BuildContext context, {
    // slightly smaller logical defaults to produce more compact markers on mobile
    double categoryLogicalSize = 40.0,
    double userLogicalSize = 48.0,
    bool preloadUserIcon = true,
  }) async {
    if (_preloaded) return;
    _preloaded = true;
    try {
      await MarkerService.instance.preloadCategoryMarkers(
        context,
        logicalSize: categoryLogicalSize,
      );
      if (!context.mounted) return;
      await MarkerService.instance.preloadAdvisoryMarkers(
        context,
        logicalSize: categoryLogicalSize,
      );
      if (preloadUserIcon) {
        // Add a mounted check before using context after await
        if (context.mounted) {
          _userIcon = await MarkerService.instance.getCustomUserMarker(
            context,
            logicalSize: userLogicalSize,
          );
        }
      }
    } catch (e) {
      // silent fail
    }
  }

  /// Ensure user icon is loaded and return it.
  Future<BitmapDescriptor?> ensureUserIcon(
    BuildContext context, {
    double logicalSize = 48.0,
  }) async {
    _userIcon ??= await MarkerService.instance.getCustomUserMarker(
      context,
      logicalSize: logicalSize,
    );
    return _userIcon;
  }

  BitmapDescriptor? get userIcon => _userIcon;

  /// Build markers for a list of "report-like" maps (same shape used in Home).
  /// Returns a Set Marker and caches markers by `id`.
  Future<Set<Marker>> buildMarkersFromReports(
    List<Map<String, dynamic>> reports, {
    required BuildContext context,
    double logicalSize = 40.0,
  }) async {
    final List<Future<Marker?>> futures = [];
    for (final r in reports) {
      final id = r['id'] as String? ?? UniqueKey().toString();
      if (_reportMarkerCache.containsKey(id)) {
        futures.add(Future.value(_reportMarkerCache[id]));
        continue;
      }
      futures.add(
        _toMarkerSafe(
          MarkerService.instance.buildReportMarkerAsync(
            id: id,
            position: LatLng(r['lat'] as double, r['lng'] as double),
            category: r['category'] as ReportCategory,
            title: r['title'] as String,
            snippet: r['snippet'] as String,
            context: context,
            logicalSize: logicalSize,
          ),
          context: 'report:$id',
        ).then((marker) {
          if (marker != null) _reportMarkerCache[id] = marker;
          return marker;
        }),
      );
    }

    final results = await Future.wait<Marker?>(futures);
    return results.whereType<Marker>().toSet();
  }

  /// Build markers from actual ReportData objects.
  /// Only include pending and verified reports. Excludes flagged and resolved.
  /// [onTap] will be called with the ReportData when marker is tapped.
  Future<Set<Marker>> buildMarkersFromReportData(
    List<ReportData> reports, {
    required BuildContext context,
    double logicalSize = 40.0,
    void Function(ReportData)? onTap,
  }) async {
    final List<Future<Marker?>> futures = [];
    final incomingIds = <String>{};

    for (final r in reports) {
      // Skip inactive/flagged/resolved reports
      if (!r.isActive) continue;
      if (r.isFlagged || r.isResolved) continue;

      final isPending = !r.isVerified && !r.isResolved && !r.isFlagged;
      final isVerified = r.isVerified && !r.isResolved && !r.isFlagged;
      if (!(isPending || isVerified)) continue;

      final id = r.reportId;
      incomingIds.add(id);

      // If we already have a cached marker, reuse immediately.
      final prev = _reportMarkerCache[id];
      if (prev != null) {
        futures.add(Future.value(prev));
        continue;
      }

      // Fast synchronous fallback: if the category icon is already cached (preloaded)
      // create a Marker synchronously to avoid triggering image decode work.
      final cachedIcon = MarkerService.instance.getCachedCategoryIcon(
        r.category,
      );
      if (cachedIcon != null) {
        final m = Marker(
          markerId: MarkerId(id),
          position: LatLng(r.latitude, r.longitude),
          icon: cachedIcon,
          infoWindow: InfoWindow.noText,
          anchor: const Offset(0.5, 1.0),
          onTap: onTap == null ? null : () => onTap(r),
        );
        _reportMarkerCache[id] = m;
        futures.add(Future.value(m));
        continue;
      }

      // No cached icon: create a fast default marker immediately, and schedule
      // the async icon load which will replace the marker later (cache first wins).
      final fallback = Marker(
        markerId: MarkerId(id),
        position: LatLng(r.latitude, r.longitude),
        icon:
            MarkerService.instance.getCachedCategoryIcon(r.category) ??
            MarkerService.instance.defaultMarkerForCategory(r.category),
        infoWindow: InfoWindow.noText,
        anchor: const Offset(0.5, 1.0),
        onTap: onTap == null ? null : () => onTap(r),
      );
      _reportMarkerCache[id] = fallback;
      futures.add(Future.value(fallback));

      // Kick off async load to prepare the proper icon and update cache/marker for future builds.
      unawaited(
        MarkerService.instance
            .getCategoryMarker(
              r.category,
              context: context,
              logicalSize: logicalSize,
            )
            .then((icon) {
              // Replace the cached Marker with the one using the actual icon.
              final updated = fallback.copyWith(iconParam: icon);
              _reportMarkerCache[id] = updated;
            })
            .catchError((_) {
              // ignore load failures (fallback remains)
            }),
      );
    }

    // Prune cache entries not present in incoming set to avoid stale markers
    final toRemove = _reportMarkerCache.keys
        .where((k) => !incomingIds.contains(k))
        .toList();
    for (final k in toRemove) {
      _reportMarkerCache.remove(k);
    }

    if (futures.isEmpty) return _reportMarkerCache.values.toSet();
    final results = await Future.wait<Marker?>(futures);
    return results.whereType<Marker>().toSet();
  }

  /// Build markers from advisory list using their center; cached and incremental.
  Future<Set<Marker>> buildMarkersFromAdvisories(
    List<Advisory> advisories, {
    required BuildContext context,
    double logicalSize = 40.0,
    void Function(Advisory)? onTap,
  }) async {
    // Only show advisories whose persisted status is ACTIVE.
    // The server-side job must update statuses (no runtime-derived helpers).
    final activeAdvisories = advisories
        .where((a) => a.status == AdvisoryStatus.active)
        .toList();

    final List<Future<Marker?>> futures = [];
    final incomingIds = <String>{};

    for (final a in activeAdvisories) {
      final id = a.advisoryId.isNotEmpty
          ? a.advisoryId
          : UniqueKey().toString();
      incomingIds.add(id);

      // Determine marker position (prefer explicit center, else compute)
      LatLng? pos = a.center ?? Advisory.computeCenter(a.affectedRoads);
      if (pos == null) continue;

      final cat = AdvisoryCategory.findById(a.advisoryType);
      if (cat == null) continue;

      // Build meta hash to detect changes
      final meta =
          '${pos.latitude.toStringAsFixed(6)}|${pos.longitude.toStringAsFixed(6)}|${a.status.name}|${cat.id}|${a.placeName ?? ''}';
      final prevMeta = _advisoryMarkerMeta[id];

      if (prevMeta == meta && _advisoryMarkerCache.containsKey(id)) {
        futures.add(Future.value(_advisoryMarkerCache[id]));
        continue;
      }

      // Use safe conversion to guard against platform/interop anomalies.
      futures.add(
        _toMarkerSafe(
          MarkerService.instance.buildAdvisoryMarkerAsync(
            id: id,
            position: pos,
            category: cat,
            title: cat.title,
            snippet: a.placeName ?? a.barangay,
            context: context,
            logicalSize: logicalSize,
            onTap: onTap == null ? null : () => onTap(a),
          ),
          context: 'advisory:$id',
        ).then((m) {
          if (m != null) {
            _advisoryMarkerCache[id] = m;
            _advisoryMarkerMeta[id] = meta;
          } else {
            // Log and keep fallback (if any) but don't crash Future.wait
            debugPrint(
              '[MarkerManager] advisory marker build returned null for $id',
            );
          }
          return m;
        }),
      );
    }

    // Prune markers that are no longer present (including those that became non-active)
    final toRemove = _advisoryMarkerCache.keys
        .where((k) => !incomingIds.contains(k))
        .toList();
    for (final k in toRemove) {
      _advisoryMarkerCache.remove(k);
      _advisoryMarkerMeta.remove(k);
    }

    if (futures.isEmpty) return _advisoryMarkerCache.values.toSet();
    final results = await Future.wait<Marker?>(futures);
    return results.whereType<Marker>().toSet();
  }

  /// Add or replace a user-location marker inside the provided [markers] set.
  /// Returns true if markers were modified.
  bool addOrUpdateUserMarker(Set<Marker> markers, LatLng pos) {
    const userId = 'user_location';
    // Remove any existing marker with same id to avoid duplicates
    markers.removeWhere((m) => m.markerId.value == userId);

    final userMarker = Marker(
      markerId: const MarkerId(userId),
      position: pos,
      icon:
          _userIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'You are here'),
      anchor: const Offset(0.5, 1.0),
    );

    markers.add(userMarker);
    return true;
  }

  /// Clear caches (for testing / memory reclaim).
  void clearCache() {
    _reportMarkerCache.clear();
    _advisoryMarkerCache.clear();
    _advisoryMarkerMeta.clear();
    _userIcon = null;
    _preloaded = false;
  }

  void dispose() {
    clearCache();
  }
}
