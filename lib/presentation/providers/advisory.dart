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

  // Current statuses used for stream queries (null => no restriction / all)
  List<AdvisoryStatus>? _currentStatuses;

  /// Expose current statuses so callers (UI) can restart streams consistently
  List<AdvisoryStatus>? get currentStatuses => _currentStatuses;

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
  }) async {
    // cancel previous subscription
    await _advisorySub?.cancel();
    _currentFilter = initialFilter;
    _filterBarangay = barangay;
    // persist statuses for later reloads (create/update/delete/refresh)
    _currentStatuses = statuses;

    if (!useRealtime) {
      // fallback to one-time fetch for maintenance scripts, etc.
      await loadAdvisories(barangay: barangay);
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      // If statuses were provided, pass them to the service; otherwise watch all.
      _advisorySub = _service
          .watchAdvisories(barangay: barangay, statuses: _currentStatuses)
          .listen(
            (list) {
              _advisories = list;
              _applyFilter();
              _setLoading(false);
            },
            onError: (err) {
              _error = err?.toString();
              _setLoading(false);
              debugPrint('❌ Advisory stream error: $err');
            },
          );
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      debugPrint('❌ Error starting advisory stream: $e');
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
    );
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
      // reload using same stream restrictions (statuses) and barangay
      await startAdvisoryStream(
        barangay: _filterBarangay,
        useRealtime: true,
        initialFilter: _currentFilter,
        statuses: _currentStatuses,
      );
      _setLoading(false);
      return id;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      debugPrint('❌ Error creating advisory: $e');
      return null;
    }
  }

  /// Update existing advisory
  Future<bool> updateAdvisory(Advisory advisory) async {
    _setLoading(true);
    _error = null;

    try {
      await _service.updateAdvisory(advisory);
      await startAdvisoryStream(
        barangay: _filterBarangay,
        useRealtime: true,
        initialFilter: _currentFilter,
        statuses: _currentStatuses,
      );
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
      await startAdvisoryStream(
        barangay: _filterBarangay,
        useRealtime: true,
        initialFilter: _currentFilter,
        statuses: _currentStatuses,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      debugPrint('❌ Error deleting advisory: $e');
      return false;
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
        _filteredAdvisories = List.from(_advisories);
        break;
      case AdvisoryViewFilter.active:
        // Show persisted-active advisories only
        _filteredAdvisories = _advisories
            .where((a) => a.status == AdvisoryStatus.active)
            .toList();
        break;
      case AdvisoryViewFilter.scheduled:
        _filteredAdvisories = _advisories
            .where((a) => a.status == AdvisoryStatus.scheduled)
            .toList();
        break;
      case AdvisoryViewFilter.inactive:
        _filteredAdvisories = _advisories
            .where((a) => a.status == AdvisoryStatus.inactive)
            .toList();
        break;
      case AdvisoryViewFilter.expired:
        _filteredAdvisories = _advisories
            .where((a) => a.status == AdvisoryStatus.expired)
            .toList();
        break;
      case AdvisoryViewFilter.byBarangay:
        if (_filterBarangay != null) {
          _filteredAdvisories = _advisories
              .where((a) => a.barangay == _filterBarangay)
              .toList();
        } else {
          _filteredAdvisories = List.from(_advisories);
        }
        break;
    }
  }

  /// Search advisories by query (now optimized for place name).
  void searchAdvisories(String query) {
    if (query.trim().isEmpty) {
      _applyFilter();
      notifyListeners();
      return;
    }

    final q = query.trim().toLowerCase();

    // Prefer searching placeName first for better UX/performance.
    _filteredAdvisories = _advisories.where((a) {
      final place = (a.placeName ?? '').toLowerCase();
      if (place.isNotEmpty && place.contains(q)) return true;

      // Fallback: match barangay, reason, or type
      final barangay = a.barangay.toLowerCase();
      final reason = a.reason.toLowerCase();
      final type = a.advisoryType.toLowerCase();

      return barangay.contains(q) || reason.contains(q) || type.contains(q);
    }).toList();

    notifyListeners();
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
    _advisorySub?.cancel();
    clearAllPlotting();
    _advisories.clear();
    _filteredAdvisories.clear();
    super.dispose();
  }
}
