import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vcroad/data/repositories/marker.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/data/models/advisory.dart';

/// Encapsulates MarkerService usage and caches results to avoid repeated I/O.
class MarkerManager {
  bool _preloaded = false;
  Widget? _userIcon;
  final Map<String, Marker> _reportMarkerCache = {};

  // Advisory caches
  final Map<String, Marker> _advisoryMarkerCache = {};
  final Map<String, String> _advisoryMarkerMeta = {}; // id -> hash meta

  // Helper: safely convert a dynamic / FutureOr result into a Marker or null.
  Future<Marker?> _toMarkerSafe(dynamic maybe, {String? context}) async {
    try {
      if (maybe is Marker) return maybe;
      if (maybe is Future) {
        final res = await maybe;
        if (res is Marker) return res;
        debugPrint(
          '[MarkerManager] Invalid marker result${context != null ? ' ($context)' : ''}: ${res.runtimeType}',
        );
        return null;
      }
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
  Future<Widget?> ensureUserIcon(
    BuildContext context, {
    double logicalSize = 48.0,
  }) async {
    _userIcon ??= await MarkerService.instance.getCustomUserMarker(
      context,
      logicalSize: logicalSize,
    );
    return _userIcon;
  }

  Widget? get userIcon => _userIcon;

  /// Build markers for a list of "report-like" maps (same shape used in Home).
  Future<List<Marker>> buildMarkersFromReports(
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
    return results.whereType<Marker>().toList();
  }

  /// Build markers from actual ReportData objects.
  /// Only include pending and verified reports. Excludes flagged and resolved.
  /// [onTap] will be called with the ReportData when marker is tapped.
  Future<List<Marker>> buildMarkersFromReportData(
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
      if (_reportMarkerCache.containsKey(id)) {
        futures.add(Future.value(_reportMarkerCache[id]));
        continue;
      }

      // Kick off async build (may use preloaded icons or fall back to default).
      futures.add(
        _toMarkerSafe(
          MarkerService.instance.buildReportMarkerAsync(
            id: id,
            position: LatLng(r.latitude, r.longitude),
            category: r.category,
            title: '',
            context: context,
            logicalSize: logicalSize,
            onTap: onTap == null ? null : () => onTap(r),
          ),
          context: 'report:$id',
        ).then((marker) {
          if (marker != null) _reportMarkerCache[id] = marker;
          return marker;
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

    if (futures.isEmpty) return _reportMarkerCache.values.toList();
    final results = await Future.wait<Marker?>(futures);
    return results.whereType<Marker>().toList();
  }

  /// Build markers from advisory list using their center; cached and incremental.
  Future<List<Marker>> buildMarkersFromAdvisories(
    List<Advisory> advisories, {
    required BuildContext context,
    double logicalSize = 40.0,
    void Function(Advisory)? onTap,
  }) async {
    // Only show advisories whose persisted status is ACTIVE.
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

    if (futures.isEmpty) return _advisoryMarkerCache.values.toList();
    final results = await Future.wait<Marker?>(futures);
    return results.whereType<Marker>().toList();
  }

  /// Add a user-location marker to the end of [markers].
  /// Assumes [markers] is a fresh list built per-frame to avoid duplicates.
  bool addOrUpdateUserMarker(List<Marker> markers, LatLng pos) {
    final userMarker = Marker(
      point: pos,
      child: _userIcon ??
          const Icon(Icons.location_on, color: Colors.blue, size: 48),
      alignment: Alignment.bottomCenter,
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
