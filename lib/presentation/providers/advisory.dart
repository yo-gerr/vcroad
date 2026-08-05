import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/data/repositories/advisory.dart';
import 'package:vcroad/data/repositories/place.dart';

enum AdvisoryViewFilter {
  all,
  active,
  scheduled,
  expired,
  byBarangay,
  inactive,
}

enum AdvisorySortOrder { newest, oldest, recentlyUpdated }

class AdvisoryProvider with ChangeNotifier {
  final AdvisoryService _service = AdvisoryService();
  // Incrementing tick to force map consumers to rebuild reliably
  int _mapTick = 0;
  int get mapTick => _mapTick;

  StreamSubscription<List<Advisory>>? _advisorySub;

  // State
  List<Advisory> _advisories = [];
  List<Advisory> _filteredAdvisories = [];
  bool _isLoading = false;
  String? _error;
  AdvisoryViewFilter _currentFilter = AdvisoryViewFilter.all;
  String? _filterBarangay;
  AdvisorySortOrder _sortOrder = AdvisorySortOrder.newest;

  // Current statuses used for stream queries (null => no restriction / all)
  List<AdvisoryStatus>? _currentStatuses;
  int? _streamLimit;

  /// The barangay actually scoping the live Firestore stream (independent of
  /// [AdvisoryViewFilter._filterBarangay], which regular users change
  /// client-side without touching the stream).
  String? _streamBarangay;

  /// Expose current statuses so callers (UI) can restart streams consistently
  List<AdvisoryStatus>? get currentStatuses => _currentStatuses;

  // Alert derivation: emits advisories newly added to the (user-consolidated)
  // stream after the session baseline, so popup alerts share one listener.
  final StreamController<Advisory> _newAdvisoryController =
      StreamController<Advisory>.broadcast();
  Stream<Advisory> get newAdvisories => _newAdvisoryController.stream;

  final Set<String> _seenIds = <String>{};
  DateTime? _baselineCreatedAt;
  bool _firstSnapshotHandled = false;

  // Map plotting state
  // NOTE: do NOT store raw GoogleMapController in the provider. Widgets own controllers.
  bool _isPlotting = false;
  bool _isPlottingAffected = true;
  List<LatLng> _currentPolylinePoints = [];
  List<List<LatLng>> _affectedRoads = [];
  List<List<LatLng>> _alternateRoutes = [];
  String? _detectedBarangay;
  String? _detectedPlaceName;

  // Undo/Redo stacks
  final List<List<List<LatLng>>> _affectedUndoStack = [];
  final List<List<List<LatLng>>> _affectedRedoStack = [];
  final List<List<List<LatLng>>> _alternateUndoStack = [];
  final List<List<List<LatLng>>> _alternateRedoStack = [];

  // Getters
  List<Advisory> get advisories => _advisories;
  List<Advisory> get filteredAdvisories => _filteredAdvisories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AdvisoryViewFilter get currentFilter => _currentFilter;
  String? get filterBarangay => _filterBarangay;
  AdvisorySortOrder get sortOrder => _sortOrder;

  /// Current stream retry/backoff attempt (0 => healthy stream). Lets the UI
  /// surface a "Reconnecting…" chip while transient errors are retried.
  int get retryAttempt => _retryAttempt;

  /// Change how the filtered list is ordered (client-side).
  void setSortOrder(AdvisorySortOrder order) {
    if (order == _sortOrder) return;
    _sortOrder = order;
    _applyFilter();
    notifyListeners();
  }

  // Map plotting getters
  bool get isPlotting => _isPlotting;
  List<LatLng> get currentRoute => _currentPolylinePoints;
  List<LatLng> get currentPolylinePoints => _currentPolylinePoints;
  List<List<LatLng>> get affectedRoads => _affectedRoads;
  List<List<LatLng>> get alternateRoutes => _alternateRoutes;
  bool get isPlottingAffected => _isPlottingAffected;
  String? get detectedBarangay => _detectedBarangay;
  String? get detectedPlaceName => _detectedPlaceName;
  bool get canUndoAffected => _affectedUndoStack.isNotEmpty;
  bool get canRedoAffected => _affectedRedoStack.isNotEmpty;
  bool get canUndoAlternate => _alternateUndoStack.isNotEmpty;
  bool get canRedoAlternate => _alternateRedoStack.isNotEmpty;

  // Computed center for current plotting
  LatLng? get currentCenter {
    final roads = _isPlottingAffected ? _affectedRoads : _alternateRoutes;
    return Advisory.computeCenter(roads);
  }

  /// Initialize provider and load advisories
  Future<void> initialize({String? barangay}) async {
    await loadAdvisories(barangay: barangay);
  }

  /// Start streaming advisories; will keep _advisories updated in realtime.
  /// Call with barangay to limit to that barangay, or null for all.
  /// Pass [statuses] to restrict the query (e.g. [active, scheduled] for normal users).
  Future<void> startAdvisoryStream({
    String? barangay,
    bool useRealtime = true,
    AdvisoryViewFilter initialFilter = AdvisoryViewFilter.all,
    List<AdvisoryStatus>? statuses,
    int? limit,
  }) async {
    // cancel previous subscription
    await _advisorySub?.cancel();
    _currentFilter = initialFilter;
    _filterBarangay = barangay;
    _streamBarangay = barangay;
    // persist statuses for later reloads (create/update/delete/refresh)
    _currentStatuses = statuses;
    _streamLimit = limit;

    if (!useRealtime) {
      // fallback to one-time fetch for maintenance scripts, etc.
      await loadAdvisories(barangay: barangay);
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      _subscribeWithRetry(
        () => _service.watchAdvisories(
          barangay: barangay,
          statuses: _currentStatuses,
          limit: limit,
        ),
      );
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      debugPrint('❌ Error starting advisory stream: $e');
    }
  }

  /// Start (or reuse) the consolidated stream for regular users: all barangays,
  /// statuses active + scheduled. This single listener powers the home map, the
  /// advisory list, and the new-advisory alert popups.
  Future<void> startUserStream() async {
    const statuses = [AdvisoryStatus.active, AdvisoryStatus.scheduled];
    final alreadyUserStream =
        _advisorySub != null &&
        _currentStatuses != null &&
        _currentStatuses!.length == statuses.length &&
        statuses.every(_currentStatuses!.contains);
    if (alreadyUserStream) return;

    await startAdvisoryStream(
      barangay: null,
      useRealtime: true,
      initialFilter: AdvisoryViewFilter.all,
      statuses: statuses,
    );
  }

  // Current retry/backoff state (per stream generation).
  int _retryAttempt = 0;
  Timer? _retryTimer;

  /// Subscribe to [buildStream], automatically resubscribing with exponential
  /// backoff on transient errors. Gives up after a bounded number of attempts.
  /// [onFirst] fires once the first emission (or terminal error) arrives,
  /// which lets callers await a full reload cycle (e.g. pull-to-refresh).
  void _subscribeWithRetry(
    Stream<List<Advisory>> Function() buildStream, {
    VoidCallback? onFirst,
  }) {
    _retryTimer?.cancel();
    _advisorySub?.cancel();
    // Each subscription starts fresh: the first emission sets the alert
    // baseline so historical documents never trigger popups.
    _firstSnapshotHandled = false;

    _advisorySub = buildStream().listen(
      (list) {
        _retryAttempt = 0; // success resets backoff
        _advisories = list;
        _applyFilter();
        _setLoading(false);
        _deriveNewAdvisories(list);
        onFirst?.call();
      },
      onError: (err) {
        _error = err?.toString();
        _setLoading(false);
        debugPrint('❌ Advisory stream error: $err');
        onFirst?.call();
        if (_retryAttempt < _maxRetryAttempts) {
          _retryAttempt += 1;
          final delay = Duration(
            milliseconds: 500 * (1 << (_retryAttempt - 1)).clamp(1, 30),
          );
          debugPrint(
            '↻ Resubscribing advisory stream in ${delay.inMilliseconds}ms '
            '(attempt $_retryAttempt/$_maxRetryAttempts)',
          );
          _retryTimer = Timer(delay, () {
            if (_disposed) return;
            try {
              _subscribeWithRetry(buildStream);
            } catch (e) {
              debugPrint('❌ Failed to resubscribe: $e');
            }
          });
        }
      },
      onDone: () {
        // Streams don't emit done normally, but resubscribe defensively.
        onFirst?.call();
        if (_retryAttempt < _maxRetryAttempts && !_disposed) {
          _subscribeWithRetry(buildStream);
        }
      },
    );
  }

  static const int _maxRetryAttempts = 5;
  bool _disposed = false;

  /// Detect advisories that newly appeared since the session baseline and emit
  /// them on [newAdvisories]. The first emission only establishes the baseline
  /// (newest `createdAt`) so pre-existing documents don't trigger alerts.
  void _deriveNewAdvisories(List<Advisory> list) {
    DateTime? newest;
    for (final a in list) {
      if (newest == null || a.createdAt.isAfter(newest)) newest = a.createdAt;
    }

    if (!_firstSnapshotHandled) {
      _firstSnapshotHandled = true;
      if (newest != null) _baselineCreatedAt = newest;
      _seenIds.addAll(list.map((a) => a.advisoryId));
      return;
    }

    final newOnes = <Advisory>[];
    for (final a in list) {
      if (_seenIds.contains(a.advisoryId)) continue;
      if (_baselineCreatedAt != null &&
          !a.createdAt.isAfter(_baselineCreatedAt!)) {
        continue;
      }
      newOnes.add(a);
    }

    _seenIds.addAll(list.map((a) => a.advisoryId));
    if (newOnes.isEmpty) return;
    for (final a in newOnes) {
      _newAdvisoryController.add(a);
    }
  }

  /// Load all advisories with optional barangay filter
  Future<void> loadAdvisories({String? barangay}) async {
    // Prefer realtime subscription for interactive UI. Reuse previously selected
    // statuses so role-based restrictions persist across reloads.
    await startAdvisoryStream(
      barangay: barangay,
      useRealtime: true,
      initialFilter: _currentFilter,
      statuses: _currentStatuses,
      limit: _streamLimit,
    );
  }

  /// Manual full reload: re-subscribes the stream and completes once the first
  /// snapshot arrives (or a terminal error occurs). Used by pull-to-refresh and
  /// the desktop refresh action.
  Future<void> refresh() async {
    _retryAttempt = 0;
    final completer = Completer<void>();
    void mark() {
      if (!completer.isCompleted) completer.complete();
    }

    _subscribeWithRetry(
      () => _service.watchAdvisories(
        barangay: _streamBarangay,
        statuses: _currentStatuses,
        limit: _streamLimit,
      ),
      onFirst: mark,
    );
    await completer.future;
  }

  /// Get active advisories (currently in effect)
  List<Advisory> getActiveAdvisories() {
    return _advisories.where((a) => a.status == AdvisoryStatus.active).toList();
  }

  /// Get advisories for specific barangay
  List<Advisory> getAdvisoriesByBarangay(String barangay) {
    return _advisories.where((a) => a.barangay == barangay).toList();
  }

  /// Create new advisory
  Future<String?> createAdvisory(Advisory advisory) async {
    _setLoading(true);
    _error = null;

    try {
      final id = await _service.createAdvisory(advisory);
      // The realtime stream pushes the new doc automatically; only reload if
      // the stream isn't active (e.g. after a failure).
      await _reloadIfNotStreaming();
      _setLoading(false);
      return id;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      debugPrint('❌ Error creating advisory: $e');
      return null;
    }
  }

  /// Generate a Firestore document identifier for an advisory that has not
  /// been written yet (used to key media uploads ahead of the doc write).
  String generateAdvisoryId() => _service.generateAdvisoryId();

  /// Update existing advisory
  Future<bool> updateAdvisory(Advisory advisory) async {
    _setLoading(true);
    _error = null;

    try {
      await _service.updateAdvisory(advisory);
      await _reloadIfNotStreaming();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      debugPrint('❌ Error updating advisory: $e');
      return false;
    }
  }

  /// Delete advisory
  Future<bool> deleteAdvisory(String advisoryId) async {
    _setLoading(true);
    _error = null;

    try {
      await _service.deleteAdvisory(advisoryId);
      await _reloadIfNotStreaming();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      debugPrint('❌ Error deleting advisory: $e');
      return false;
    }
  }

  /// The realtime stream handles CRUD updates on its own; this is a safety net
  /// for the rare case where the stream is not active.
  Future<void> _reloadIfNotStreaming() async {
    if (_advisorySub == null) {
      await loadAdvisories(barangay: _streamBarangay);
    }
  }

  /// Toggle advisory status (active/inactive)
  Future<bool> toggleAdvisoryStatus(String advisoryId) async {
    final advisory = _advisories.firstWhere((a) => a.advisoryId == advisoryId);
    final newStatus = advisory.status == AdvisoryStatus.active
        ? AdvisoryStatus.inactive
        : AdvisoryStatus.active;

    return updateAdvisory(
      advisory.copyWith(status: newStatus, updatedAt: DateTime.now()),
    );
  }

  /// Apply filter to advisories
  void applyFilter(AdvisoryViewFilter filter, {String? barangay}) {
    _currentFilter = filter;
    _filterBarangay = barangay;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    switch (_currentFilter) {
      case AdvisoryViewFilter.all:
        _filteredAdvisories = _applyBarangayScope(_advisories).toList();
        break;
      case AdvisoryViewFilter.active:
        // Show persisted-active advisories only
        _filteredAdvisories = _applyBarangayScope(
          _advisories.where((a) => a.status == AdvisoryStatus.active),
        ).toList();
        break;
      case AdvisoryViewFilter.scheduled:
        _filteredAdvisories = _applyBarangayScope(
          _advisories.where((a) => a.status == AdvisoryStatus.scheduled),
        ).toList();
        break;
      case AdvisoryViewFilter.inactive:
        _filteredAdvisories = _applyBarangayScope(
          _advisories.where((a) => a.status == AdvisoryStatus.inactive),
        ).toList();
        break;
      case AdvisoryViewFilter.expired:
        _filteredAdvisories = _applyBarangayScope(
          _advisories.where((a) => a.status == AdvisoryStatus.expired),
        ).toList();
        break;
      case AdvisoryViewFilter.byBarangay:
        _filteredAdvisories = _filterBarangay == null
            ? List.from(_advisories)
            : _advisories.where((a) => a.barangay == _filterBarangay).toList();
        break;
    }
    _sort();
  }

  /// Order the filtered list by the current [AdvisorySortOrder].
  void _sort() {
    switch (_sortOrder) {
      case AdvisorySortOrder.newest:
        _filteredAdvisories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case AdvisorySortOrder.oldest:
        _filteredAdvisories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case AdvisorySortOrder.recentlyUpdated:
        _filteredAdvisories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
  }

  /// Narrow a candidate set to the currently selected barangay, if any.
  /// Replaces the old "stream scoped by barangay" behavior now that regular
  /// users share a single all-barangay consolidated stream.
  Iterable<Advisory> _applyBarangayScope(Iterable<Advisory> source) {
    if (_filterBarangay == null) return source;
    return source.where((a) => a.barangay == _filterBarangay);
  }

  /// Search advisories by query. Prefers the denormalized `searchKeywords`
  /// (indexed-ready) and falls back to a substring scan for old documents.
  void searchAdvisories(String query) {
    if (query.trim().isEmpty) {
      _applyFilter();
      notifyListeners();
      return;
    }

    final q = query.trim().toLowerCase();

    _filteredAdvisories = _advisories.where((a) {
      if (_filterBarangay != null && a.barangay != _filterBarangay) {
        return false;
      }
      // Fast path: indexed token match.
      if (a.searchKeywords != null && a.searchKeywords!.isNotEmpty) {
        if (a.searchKeywords!.any((kw) => kw.contains(q))) return true;
      }

      // Fallback for legacy docs without searchKeywords.
      final place = (a.placeName ?? '').toLowerCase();
      if (place.isNotEmpty && place.contains(q)) return true;

      final barangay = a.barangay.toLowerCase();
      final reason = a.reason.toLowerCase();
      final type = a.advisoryType.toLowerCase();

      return barangay.contains(q) || reason.contains(q) || type.contains(q);
    }).toList();
    _sort();

    notifyListeners();
  }

  /// Precomputed per-status counts over the currently streamed advisories.
  Map<AdvisoryStatus, int> get statusCounts {
    final counts = <AdvisoryStatus, int>{
      AdvisoryStatus.active: 0,
      AdvisoryStatus.inactive: 0,
      AdvisoryStatus.scheduled: 0,
      AdvisoryStatus.expired: 0,
    };
    for (final a in _advisories) {
      counts[a.status] = (counts[a.status] ?? 0) + 1;
    }
    return counts;
  }

  // ===== MAP CONTROLLER METHODS =====

  /// Start plotting mode
  void startPlotting({required bool isAffected}) {
    _isPlotting = true;
    _isPlottingAffected = isAffected;
    _currentPolylinePoints.clear();
    notifyListeners();
  }

  /// Add point to current route
  void addPointToCurrentRoute(LatLng point) {
    if (!_isPlotting) return;
    _currentPolylinePoints.add(point);
    // debug
    if (kDebugMode) {
      debugPrint(
        'AdvisoryProvider: addPointToCurrentRoute -> ${point.latitude},${point.longitude} (len=${_currentPolylinePoints.length})',
      );
    }
    // bump map tick so selectors rebuild reliably
    _mapTick++;
    _detectBarangayFromPoints();
    notifyListeners();
  }

  /// Complete current route and save it
  void completeRoute() {
    if (_currentPolylinePoints.length < 2) return;

    if (_isPlottingAffected) {
      _pushToUndoStack(_affectedUndoStack, _affectedRoads);
      _affectedRedoStack.clear();
      _affectedRoads.add(List.from(_currentPolylinePoints));
    } else {
      _pushToUndoStack(_alternateUndoStack, _alternateRoutes);
      _alternateRedoStack.clear();
      _alternateRoutes.add(List.from(_currentPolylinePoints));
    }

    _currentPolylinePoints.clear();
    _isPlotting = false;
    _mapTick++;
    notifyListeners();

    // After route added, compute center and attempt place/barangay detection (async)
    _detectPlaceAndBarangayForCurrentData();
  }

  /// Called after plotting changes or when loading existing advisory
  Future<void> _detectPlaceAndBarangayForCurrentData() async {
    try {
      final center = currentCenter;
      if (center == null) return;

      // Detect barangay (existing implementation uses service)
      final barangay = await _service.detectBarangay(center);
      if (barangay != null && barangay != _detectedBarangay) {
        _detectedBarangay = barangay;
      }

      // Detect human-friendly place name (reverse geocode) using PlaceService instance.
      // PlaceService exposes getAddressFromCoordinates(lat, lng) which returns a
      // formatted address. Use the singleton instance and avoid creating new instances.
      final placeService = PlaceService.instance;
      final placeName = await placeService.getAddressFromCoordinates(
        center.latitude,
        center.longitude,
      );

      if (placeName != _detectedPlaceName) {
        _detectedPlaceName = placeName;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error detecting place/barangay: $e');
    }
  }

  /// Cancel current plotting
  void cancelPlotting() {
    _currentPolylinePoints.clear();
    _isPlotting = false;
    _mapTick++;
    notifyListeners();
  }

  /// Snap current route using service and replace current points with snapped result.
  /// Returns true on success, false on failure.
  Future<bool> snapToRoad() async {
    if (_currentPolylinePoints.length < 2) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapped = await _service.snapToRoad(_currentPolylinePoints);

      if (snapped.isEmpty) {
        // treat empty as fallback (original points kept by service)
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _currentPolylinePoints = List.from(snapped);
      _mapTick++;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Snap failed: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Detect barangay from plotted points
  Future<void> _detectBarangayFromPoints() async {
    if (_currentPolylinePoints.isEmpty) return;

    // Use first point for detection
    final point = _currentPolylinePoints.first;
    try {
      final barangay = await _service.detectBarangay(point);
      if (barangay != null && barangay != _detectedBarangay) {
        _detectedBarangay = barangay;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error detecting barangay: $e');
    }
  }

  /// Toggle between plotting affected roads and alternate routes
  void togglePlottingMode() {
    _isPlottingAffected = !_isPlottingAffected;
    _currentPolylinePoints.clear();
    notifyListeners();
  }

  /// Add point to current polyline
  void addPointToPolyline(LatLng point) {
    _currentPolylinePoints.add(point);
    notifyListeners();
  }

  /// Complete current polyline and start new one
  void completeCurrentPolyline() {
    if (_currentPolylinePoints.isEmpty) return;

    if (_isPlottingAffected) {
      _pushToUndoStack(_affectedUndoStack, _affectedRoads);
      _affectedRedoStack.clear();
      _affectedRoads.add(List.from(_currentPolylinePoints));
    } else {
      _pushToUndoStack(_alternateUndoStack, _alternateRoutes);
      _alternateRedoStack.clear();
      _alternateRoutes.add(List.from(_currentPolylinePoints));
    }

    _currentPolylinePoints.clear();
    notifyListeners();
  }

  /// Update entire polyline with snapped points
  void updateCurrentPolyline(List<LatLng> snappedPoints) {
    _currentPolylinePoints = snappedPoints;
    notifyListeners();
  }

  /// Remove last point from current polyline
  void removeLastPoint() {
    if (_currentPolylinePoints.isNotEmpty) {
      _currentPolylinePoints.removeLast();
      notifyListeners();
    }
  }

  /// Undo last polyline
  void undoLastPolyline() {
    if (_isPlottingAffected && _affectedUndoStack.isNotEmpty) {
      _pushToRedoStack(_affectedRedoStack, _affectedRoads);
      _affectedRoads = _affectedUndoStack.removeLast();
    } else if (!_isPlottingAffected && _alternateUndoStack.isNotEmpty) {
      _pushToRedoStack(_alternateRedoStack, _alternateRoutes);
      _alternateRoutes = _alternateUndoStack.removeLast();
    }
    notifyListeners();
  }

  /// Redo last undone polyline
  void redoLastPolyline() {
    if (_isPlottingAffected && _affectedRedoStack.isNotEmpty) {
      _pushToUndoStack(_affectedUndoStack, _affectedRoads);
      _affectedRoads = _affectedRedoStack.removeLast();
    } else if (!_isPlottingAffected && _alternateRedoStack.isNotEmpty) {
      _pushToUndoStack(_alternateUndoStack, _alternateRoutes);
      _alternateRoutes = _alternateRedoStack.removeLast();
    }
    notifyListeners();
  }

  /// Clear all polylines for current mode
  void clearCurrentPolylines() {
    if (_isPlottingAffected) {
      if (_affectedRoads.isNotEmpty) {
        _pushToUndoStack(_affectedUndoStack, _affectedRoads);
        _affectedRedoStack.clear();
        _affectedRoads.clear();
      }
    } else {
      if (_alternateRoutes.isNotEmpty) {
        _pushToUndoStack(_alternateUndoStack, _alternateRoutes);
        _alternateRedoStack.clear();
        _alternateRoutes.clear();
      }
    }
    _currentPolylinePoints.clear();
    _mapTick++;
    notifyListeners();
  }

  /// Clear all plotting data
  void clearAllPlotting() {
    _currentPolylinePoints.clear();
    _affectedRoads.clear();
    _alternateRoutes.clear();
    _affectedUndoStack.clear();
    _affectedRedoStack.clear();
    _alternateUndoStack.clear();
    _alternateRedoStack.clear();
    _detectedBarangay = null;
    _detectedPlaceName = null;
    _isPlottingAffected = true;
    _mapTick++;
    notifyListeners();
  }

  /// Set detected barangay from polygon matching
  void setDetectedBarangay(String? barangay) {
    _detectedBarangay = barangay;
    notifyListeners();
  }

  /// Load existing advisory data for editing
  void loadAdvisoryForEditing(Advisory advisory) {
    _affectedRoads = advisory.affectedRoads != null
        ? advisory.affectedRoads!
              .map((poly) => List<LatLng>.from(poly))
              .toList()
        : [];
    _alternateRoutes = advisory.alternateRoutes != null
        ? advisory.alternateRoutes!
              .map((poly) => List<LatLng>.from(poly))
              .toList()
        : [];
    _detectedBarangay = advisory.barangay;
    _detectedPlaceName = advisory.placeName;
    _currentPolylinePoints.clear();
    _affectedUndoStack.clear();
    _affectedRedoStack.clear();
    _alternateUndoStack.clear();
    _alternateRedoStack.clear();
    notifyListeners();

    // If no placeName stored, try to detect from center async
    if (_detectedPlaceName == null) {
      final center = advisory.center ?? Advisory.computeCenter(_affectedRoads);
      if (center != null) {
        // fire-and-forget detection
        _detectPlaceAndBarangayForCurrentData();
      }
    }
  }

  void _pushToUndoStack(
    List<List<List<LatLng>>> stack,
    List<List<LatLng>> current,
  ) {
    // Deep copy to prevent reference issues
    stack.add(current.map((poly) => List<LatLng>.from(poly)).toList());
    // Limit stack size to prevent memory issues
    if (stack.length > 20) {
      stack.removeAt(0);
    }
    // not incrementing tick here; caller should increment if needed
  }

  void _pushToRedoStack(
    List<List<List<LatLng>>> stack,
    List<List<LatLng>> current,
  ) {
    stack.add(current.map((poly) => List<LatLng>.from(poly)).toList());
    if (stack.length > 20) {
      stack.removeAt(0);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Dispose and cleanup
  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _advisorySub?.cancel();
    _newAdvisoryController.close();
    clearAllPlotting();
    _advisories.clear();
    _filteredAdvisories.clear();
    super.dispose();
  }
}
