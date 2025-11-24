import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/advisory.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/services/place.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/home/map_controls.dart';
import 'package:vcroad_v2/shared/widgets/home/marker.dart';
import 'package:vcroad_v2/shared/widgets/home/user_stats.dart';
import 'package:vcroad_v2/shared/widgets/home/report_stats.dart';
import 'package:vcroad_v2/shared/widgets/home/category.dart';
import 'package:vcroad_v2/shared/models/report.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/utils/search/search_place.dart';
import 'package:vcroad_v2/shared/widgets/home/map.dart';
import 'package:vcroad_v2/shared/services/account.dart';
import 'package:vcroad_v2/shared/models/stats.dart';
import 'package:vcroad_v2/shared/widgets/home/barangay_user_stats.dart';
import 'package:vcroad_v2/shared/providers/advisory.dart';
import 'package:vcroad_v2/shared/utils/dialog/advisory.dart';
import 'package:vcroad_v2/shared/utils/dialog/report.dart'; // add
import 'package:vcroad_v2/shared/providers/report.dart'; // add
import 'package:vcroad_v2/shared/providers/location.dart';
import 'package:vcroad_v2/shared/utils/debouncer/debouncer.dart'; // add
import 'package:vcroad_v2/shared/widgets/home/barangay_report_stats.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vcroad_v2/shared/services/google_sheets.dart';
import 'package:vcroad_v2/shared/utils/dialog/loading.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  ReportProvider? _reportProviderRef;
  VoidCallback? _reportProviderListener;
  int _mapRecreateId = 0;
  MapCategory _selectedCategory = MapCategory.all;
  Set<Marker> _markers = {};
  Set<Marker> _reportMarkers = {};
  Set<Marker> _advisoryMarkers = {};

  bool _isSysAdmin = false;

  final ScrollController _dashboardScrollController = ScrollController();
  final DraggableScrollableController _dashboardSheetController =
      DraggableScrollableController();
  double _dashboardSheetFraction = 0.4;

  bool _isPointerOverDashboard = false;
  bool _isTrafficEnabled = false;

  LatLng? _userLocation;
  static const double _userZoom = 17.0;

  bool _animateToUserWhenMapReady = false;

  final Map<ReportCategory, int> _reportCounts = {
    ReportCategory.roadObstruction: 2,
    ReportCategory.roadAccident: 6,
    ReportCategory.roadFlooding: 9,
    ReportCategory.outdatedPosters: 2,
    ReportCategory.roadConstruction: 1,
    ReportCategory.brokenSignage: 1,
  };

  static const LatLng _valenzuelaCityCenter = LatLng(14.7006, 120.9830);

  bool _followUser = true;
  bool _isProgrammaticCamera = false;

  LocationProvider? _locationProviderRef;
  VoidCallback? _locationProviderListener;

  bool _markersPrepared = false;
  final MarkerManager _markerManager = MarkerManager();

  Map<String, int>? _userStats;
  String? _userStatsError;

  List<BarangayUserStat>? _perBarangayStats;
  bool _isPerBarangayLoading = false;

  VoidCallback? _dashboardSheetListener;
  VoidCallback? _advisoryProviderListener;
  AdvisoryProvider? _advisoryProviderRef;

  final Debouncer _reportDebouncer = Debouncer(
    const Duration(milliseconds: 250),
  );
  Timer? _reportRebuildTimer;
  bool _isBuildingReportMarkers = false;
  final Debouncer _advisoryDebouncer = Debouncer(
    const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachReportListener(); // add listener for report provider
      final userProv = Provider.of<UserProvider>(context, listen: false);
      final wasSys = _isSysAdmin;
      _isSysAdmin = userProv.isSysAdmin;

      if (_isSysAdmin && !wasSys) {
        _dashboardSheetListener = () {
          setState(() {
            _dashboardSheetFraction = _dashboardSheetController.size;
          });
        };
        _dashboardSheetController.addListener(_dashboardSheetListener!);
      }

      _animateToUserWhenMapReady = true;
      context.read<LocationProvider>().start();

      _prepareMarkersAndUserIcon();
      _attachAdvisoryListener();
      _attachLocationProviderListener();
      _fetchUserStats();
    });
  }

  // Listen to ReportProvider and rebuild report markers on changes.
  void _attachReportListener() {
    final rp = Provider.of<ReportProvider>(context, listen: false);
    _reportProviderRef = rp;
    final up = Provider.of<UserProvider>(context, listen: false);
    String? barangayParam;
    if (up.isAdmin && !up.isSysAdmin) {
      barangayParam = up.user?.barangay.name;
    }

    // Map-focused stream: active only, excludes resolved/flagged on the server
    rp.listenMapReports(limit: 300, barangay: barangayParam);

    // Add a removable listener so we can cancel it in dispose().
    _reportProviderListener ??= () {
      _reportDebouncer.runOnce(() async {
        if (!mounted) return;
        await _rebuildReportMarkers();
      });
    };
    rp.addListener(_reportProviderListener!);

    scheduleMicrotask(_rebuildReportMarkers);
  }

  Future<void> _rebuildReportMarkers() async {
    if (!mounted) return;
    if (_isBuildingReportMarkers) {
      // a build is in progress; schedule a follow-up and return
      _reportRebuildTimer?.cancel();
      _reportRebuildTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        scheduleMicrotask(_rebuildReportMarkers);
      });
      return;
    }
    _isBuildingReportMarkers = true;
    try {
      final rp = Provider.of<ReportProvider>(context, listen: false);
      var reports = rp.allReports;

      if (kDebugMode) {
        // Concise summary always useful
        debugPrint('[Home] rebuildReportMarkers -> ${reports.length} reports');

        // Print per-category counts (compact histogram)
        final Map<ReportCategory, int> summary = {
          for (final c in ReportCategory.values) c: 0,
        };
        for (final r in reports) {
          summary[r.category] = (summary[r.category] ?? 0) + 1;
        }
        final countsStr = summary.entries
            .where((e) => e.value > 0)
            .map((e) => '${e.key.name}:${e.value}')
            .join(' | ');
        if (countsStr.isNotEmpty) debugPrint('[Home] counts: $countsStr');
      }

      final up = Provider.of<UserProvider>(context, listen: false);
      final isAdminOnly = up.isAdmin && !up.isSysAdmin;
      final adminBarangay = up.user?.barangay.name;
      if (isAdminOnly && adminBarangay != null && adminBarangay.isNotEmpty) {
        reports = reports
            .where((r) => (r.barangay).toString() == adminBarangay)
            .toList();
      }

      if (reports.isEmpty) {
        setState(() {
          _reportMarkers = {};
          // Reset counts to zeros for all categories when there are no reports
          _reportCounts
            ..clear()
            ..addEntries(ReportCategory.values.map((c) => MapEntry(c, 0)));
          _composeAndSetMarkers();
        });
        return;
      }

      final info = context.responsive;
      final built = await _markerManager.buildMarkersFromReportData(
        reports,
        context: context,
        logicalSize: info.isMobile ? 22.0 : 28.0,
        onTap: (report) {
          if (!mounted) return;
          ReportDetailsDialog.show(context, report.reportId);
        },
      );

      // Compute per-category counts once from the in-memory reports list.
      final Map<ReportCategory, int> counts = {
        for (final c in ReportCategory.values) c: 0,
      };
      for (final r in reports) {
        counts[r.category] = (counts[r.category] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _reportMarkers = built;
        _reportCounts
          ..clear()
          ..addAll(counts);
        _composeAndSetMarkers();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to build report markers: $e');
    } finally {
      _isBuildingReportMarkers = false;
    }
  }

  // Listen to advisory provider and rebuild advisory markers.
  void _attachAdvisoryListener() {
    _advisoryProviderRef ??= Provider.of<AdvisoryProvider>(
      context,
      listen: false,
    );

    // Ensure we only subscribe to ACTIVE advisories for map usage.
    final up = Provider.of<UserProvider>(context, listen: false);
    String? barangayParam;
    if (up.isAdmin && !up.isSysAdmin) {
      barangayParam = up.user?.barangay.name;
    }
    // Start stream with ACTIVE status only
    unawaited(
      _advisoryProviderRef!.startAdvisoryStream(
        barangay: barangayParam,
        useRealtime: true,
        initialFilter: AdvisoryViewFilter.active,
        statuses: const [AdvisoryStatus.active],
      ),
    );

    if (_advisoryProviderListener == null) {
      _advisoryProviderListener = () {
        scheduleMicrotask(_rebuildAdvisoryMarkers);
      };
      _advisoryProviderRef!.addListener(() {
        _advisoryDebouncer.runOnce(() async {
          if (!mounted) return;
          await _rebuildAdvisoryMarkers();
        });
      });
      _rebuildAdvisoryMarkers();
    }
  }

  // Listen to LocationProvider updates and update markers/camera as needed.
  void _attachLocationProviderListener() {
    _locationProviderRef ??= Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    if (_locationProviderListener == null) {
      _setupLocationProviderListener();
    }
  }

  // Extracted small method to keep listener setup concise.
  void _setupLocationProviderListener() {
    _locationProviderListener = () {
      if (!mounted) return;
      final lp = _locationProviderRef!;
      final newLoc = lp.location;
      if (newLoc != null) {
        final prev = _userLocation;
        final shouldAnimate =
            prev == null ||
            (Geolocator.distanceBetween(
                  prev.latitude,
                  prev.longitude,
                  newLoc.latitude,
                  newLoc.longitude,
                ) >
                2.5);
        _userLocation = newLoc;
        _composeAndSetMarkers();
        if (shouldAnimate &&
            _animateToUserWhenMapReady &&
            _mapController != null) {
          _animateToUserWhenMapReady = false;
          _animateToUser(_userLocation!, zoom: _userZoom);
        }
      }
    };
    _locationProviderRef!.addListener(_locationProviderListener!);
  }

  Future<void> _rebuildAdvisoryMarkers() async {
    if (!mounted) return;
    final advProv = Provider.of<AdvisoryProvider>(context, listen: false);
    final list = advProv.filteredAdvisories;
    try {
      final built = await _markerManager.buildMarkersFromAdvisories(
        list,
        context: context,
        logicalSize: 28.0,
        onTap: (advisory) {
          if (!mounted) return;
          AdvisoryDetailsDialog.show(context, advisory);
        },
      );
      if (!mounted) return;
      setState(() {
        _advisoryMarkers = built;
        _composeAndSetMarkers();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Advisory markers build error: $e');
    }
  }

  // Preload icons and build initial report markers.
  Future<void> _prepareMarkersAndUserIcon() async {
    if (_markersPrepared) return;
    _markersPrepared = true;
    try {
      final info = context.responsive;
      final categoryLogicalSize = info.isMobile ? 22.0 : 28.0;
      final userLogicalSize = info.isMobile ? 28.0 : 32.0;

      // Preload category/advisory/user icons (async). Do not create any sample report markers.
      await _markerManager.preload(
        context,
        categoryLogicalSize: categoryLogicalSize,
        userLogicalSize: userLogicalSize,
      );

      // Ensure user icon is ready; do not fabricate report markers here.
      if (_userLocation != null && mounted) {
        await _markerManager.ensureUserIcon(
          context,
          logicalSize: userLogicalSize,
        );
      }

      if (mounted) {
        // Keep reportMarkers empty until real provider data arrives.
        setState(() {
          _reportMarkers = {};
          _composeAndSetMarkers();
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MarkerManager error: $e');
    }
  }

  // Merge report/advisory/user markers and set to map.
  void _composeAndSetMarkers() {
    final composed = <Marker>{};
    if (_selectedCategory == MapCategory.all ||
        _selectedCategory == MapCategory.report) {
      composed.addAll(_reportMarkers);
    }
    if (_selectedCategory == MapCategory.all ||
        _selectedCategory == MapCategory.advisory) {
      composed.addAll(_advisoryMarkers);
    }
    if (_userLocation != null) {
      _markerManager.addOrUpdateUserMarker(composed, _userLocation!);
    }
    _markers = composed;
  }

  // Animate camera to the target location.
  Future<void> _animateToUser(LatLng target, {double zoom = _userZoom}) async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    try {
      _isProgrammaticCamera = true;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('animate to user error: $e');
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        _isProgrammaticCamera = false;
      });
    }
  }

  // Toggle traffic layer and show snack.
  void _toggleTrafficLayer() {
    if (_mapController == null) return;
    setState(() {
      _isTrafficEnabled = !_isTrafficEnabled;
    });
    SnackbarUtils.show(
      context,
      _isTrafficEnabled ? 'Traffic layer enabled' : 'Traffic layer disabled',
      icon: Icons.traffic,
      duration: const Duration(seconds: 1),
    );
  }

  // Center map on user; start provider if needed.
  Future<void> _centerOnUser() async {
    final locProv = context.read<LocationProvider>();
    if (locProv.location != null) {
      _userLocation = locProv.location;
      if (_mapController != null) {
        await _animateToUser(_userLocation!, zoom: _userZoom);
      } else {
        _animateToUserWhenMapReady = true;
      }
    } else {
      await locProv.start();
      if (locProv.location != null) {
        _userLocation = locProv.location;
        if (_mapController != null) {
          await _animateToUser(_userLocation!, zoom: _userZoom);
        } else {
          _animateToUserWhenMapReady = true;
        }
      }
    }
  }

  // Move map to selected place suggestion.
  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    try {
      final details = await PlaceService.instance.placeDetails(
        s.placeId,
        sessionToken: null,
      );

      if (details == null) {
        if (mounted) {
          SnackbarUtils.show(
            context,
            'Could not fetch location details',
            icon: Icons.error,
            duration: const Duration(seconds: 2),
          );
        }
        return;
      }

      if (_mapController == null) return;

      if (details.viewport != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(details.viewport!, 64),
        );
        return;
      }
      if (details.location != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: details.location!, zoom: 16.0),
          ),
        );
        return;
      }
    } catch (e, st) {
      debugPrint('[Home] Exception in _selectSuggestion: $e\n$st');
      if (mounted) {
        SnackbarUtils.show(
          context,
          'Failed to move map to location',
          icon: Icons.error,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _mapRecreateId++;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final isWideScreen = info.isDesktop || info.isTablet;

    final isLocating = context.select<LocationProvider, bool>(
      (p) => p.isLocating && p.location == null,
    );

    final isSysAdminNow = context.select((UserProvider p) => p.isSysAdmin);
    final isAdminNow = context.select(
      (UserProvider p) => p.isAdmin && !p.isSysAdmin,
    );

    if (isSysAdminNow != _isSysAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isSysAdminNow && _dashboardSheetListener == null) {
          _dashboardSheetListener = () {
            if (!mounted) return;
            setState(() {
              _dashboardSheetFraction = _dashboardSheetController.size;
            });
          };
          _dashboardSheetController.addListener(_dashboardSheetListener!);
        }
        if (!isSysAdminNow && _dashboardSheetListener != null) {
          _dashboardSheetController.removeListener(_dashboardSheetListener!);
          _dashboardSheetListener = null;
          if (mounted) {
            setState(() {
              _dashboardSheetFraction = 0.4;
            });
          }
        }
        if (mounted) setState(() => _isSysAdmin = isSysAdminNow);
      });
    }

    final now = DateTime.now();
    // Allow desktop dashboard for sysadmin OR admin on wide screens.
    final useSplitLayout = isWideScreen && (isSysAdminNow || isAdminNow);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/home.webp',
              width: info.scale(52),
              height: info.scale(52),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: useSplitLayout
          ? Row(
              children: [
                SizedBox(
                  width: info.scale(380),
                  child: _buildDesktopDashboard(
                    info,
                    now,
                    showPerBarangayButtons: isSysAdminNow,
                    isAdminViewing: isAdminNow,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      MapView(
                        mapRecreateId: _mapRecreateId,
                        initialCameraPosition: const CameraPosition(
                          target: _valenzuelaCityCenter,
                          zoom: 13,
                        ),
                        markers: _markers,
                        myLocationEnabled: true,
                        trafficEnabled: _isTrafficEnabled,
                        gesturesEnabled: true,
                        onMapCreated: (controller) async {
                          try {
                            _mapController = controller;
                            if (_animateToUserWhenMapReady &&
                                _userLocation != null) {
                              _animateToUserWhenMapReady = false;
                              await _animateToUser(
                                _userLocation!,
                                zoom: _userZoom,
                              );
                            }
                          } catch (e, st) {
                            if (kDebugMode) {
                              debugPrint('Map onMapCreated error: $e\n$st');
                            }
                          }
                        },
                        onCameraMoveStarted: () {
                          if (!_isProgrammaticCamera && _followUser) {
                            setState(() => _followUser = false);
                          }
                        },
                        onTap: (_) {
                          if (_followUser) setState(() => _followUser = false);
                        },
                      ),

                      MapSearch(
                        selectedCategory: _selectedCategory,
                        onCategoryChanged: (c) {
                          if (mounted) {
                            setState(() {
                              _selectedCategory = c;
                              _composeAndSetMarkers();
                            });
                          }
                        },
                        onSuggestionSelected: (suggestion) async {
                          await _selectSuggestion(suggestion);
                        },
                      ),

                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        right: info.scale(16),
                        bottom: _computeMapControlsBottom(info, context),
                        child: MapControls(
                          isTrafficEnabled: _isTrafficEnabled,
                          onToggleTraffic: _toggleTrafficLayer,
                          onCenterOnUser: _centerOnUser,
                          info: info,
                        ),
                      ),

                      if (isLocating)
                        Positioned(
                          top: info.scale(80),
                          left: info.scale(16),
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: EdgeInsets.all(info.scale(12)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: info.scale(16),
                                    height: info.scale(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: info.scale(8)),
                                  Text(
                                    'Fetching location...',
                                    style: TextStyle(
                                      fontSize: info.scaleFont(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                MapView(
                  mapRecreateId: _mapRecreateId,
                  initialCameraPosition: const CameraPosition(
                    target: _valenzuelaCityCenter,
                    zoom: 13,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  trafficEnabled: _isTrafficEnabled,
                  gesturesEnabled: !_isPointerOverDashboard,
                  onMapCreated: (controller) async {
                    try {
                      _mapController = controller;
                      if (_animateToUserWhenMapReady && _userLocation != null) {
                        _animateToUserWhenMapReady = false;
                        await _animateToUser(_userLocation!, zoom: _userZoom);
                      }
                    } catch (e, st) {
                      if (kDebugMode) {
                        debugPrint('Map onMapCreated error: $e\n$st');
                      }
                    }
                  },
                  onCameraMoveStarted: () {
                    if (!_isProgrammaticCamera && _followUser) {
                      setState(() => _followUser = false);
                    }
                  },
                  onTap: (_) {
                    if (_followUser) setState(() => _followUser = false);
                  },
                ),

                MapSearch(
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (c) {
                    if (mounted) {
                      setState(() {
                        _selectedCategory = c;
                        _composeAndSetMarkers();
                      });
                    }
                  },
                  onSuggestionSelected: (suggestion) async {
                    await _selectSuggestion(suggestion);
                  },
                ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  right: info.scale(16),
                  bottom: _computeMapControlsBottom(info, context),
                  child: MapControls(
                    isTrafficEnabled: _isTrafficEnabled,
                    onToggleTraffic: _toggleTrafficLayer,
                    onCenterOnUser: _centerOnUser,
                    info: info,
                  ),
                ),

                if (_isSysAdmin) ...[
                  if (isWideScreen)
                    _buildDesktopDashboard(
                      info,
                      now,
                      showPerBarangayButtons: true,
                      isAdminViewing: false,
                    )
                  else
                    _buildMobileDashboard(
                      info,
                      now,
                      showPerBarangayButtons: true,
                      isAdminViewing: false,
                    ),
                ],

                if (isLocating)
                  Positioned(
                    top: info.scale(80),
                    left: (isWideScreen && _isSysAdmin)
                        ? info.scale(396 + 16)
                        : info.scale(16),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.all(info.scale(12)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: info.scale(16),
                              height: info.scale(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: info.scale(8)),
                            Text(
                              'Fetching location...',
                              style: TextStyle(fontSize: info.scaleFont(12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _reportDebouncer.dispose();
    _advisoryDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // Remove report provider listener if attached
    if (_reportProviderListener != null && _reportProviderRef != null) {
      try {
        _reportProviderRef!.removeListener(_reportProviderListener!);
      } catch (_) {}
      _reportProviderListener = null;
      _reportProviderRef = null;
    }

    if (_locationProviderListener != null && _locationProviderRef != null) {
      _locationProviderRef!.removeListener(_locationProviderListener!);
      _locationProviderListener = null;
    }

    // Dispose map controller to avoid "used after dispose" races
    try {
      _mapController?.dispose();
    } catch (_) {}
    _mapController = null;

    _dashboardScrollController.dispose();
    if (_dashboardSheetListener != null) {
      _dashboardSheetController.removeListener(_dashboardSheetListener!);
      _dashboardSheetListener = null;
    }
    _dashboardSheetController.dispose();
    _markerManager.dispose();
    if (_advisoryProviderListener != null && _advisoryProviderRef != null) {
      _removeAdvisoryProviderRefListener();
    }
    super.dispose();
  }

  // Helper removed to reduce inline complexity.
  void _removeAdvisoryProviderRefListener() {
    _advisoryProviderRef!.removeListener(_advisoryProviderListener!);
    _advisoryProviderListener = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<LocationProvider>().start();
    }
  }

  Future<void> _fetchUserStats() async {
    if (_userStats == null) {
      setState(() {
        _userStats = {'total': 0, 'verified': 0, 'unverified': 0};
        _userStatsError = null;
      });
    }

    try {
      final stats = await AccountService.instance.getUserStats();
      if (mounted) {
        setState(() => _userStats = stats);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to fetch user stats: $e\n$st');
      }
      if (mounted) {
        setState(() => _userStatsError = 'Failed to load user stats');
      }
    }
  }

  Future<void> _showPerBarangayStats() async {
    if (_isPerBarangayLoading) return;

    if (_perBarangayStats != null && _perBarangayStats!.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (c) => BarangayUserStats(stats: _perBarangayStats!),
        ),
      );
      return;
    }

    setState(() => _isPerBarangayLoading = true);
    try {
      final stats = await AccountService.instance.getUserStatsPerBarangay(
        includeZeroEntries: true,
      );
      _perBarangayStats = stats;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (c) => BarangayUserStats(stats: stats)),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('Failed to load per-barangay stats: $e\n$st');
      if (mounted) {
        SnackbarUtils.show(
          context,
          'Failed to load per-barangay stats',
          icon: Icons.error,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _isPerBarangayLoading = false);
    }
  }

  Future<void> _showPerBarangayReportStats() async {
    if (_isPerBarangayLoading) return;
    setState(() => _isPerBarangayLoading = true);
    try {
      final rp = Provider.of<ReportProvider>(context, listen: false);
      final up = Provider.of<UserProvider>(context, listen: false);
      var reports = rp.allReports;

      // If admin (not sysadmin), limit to their barangay
      if (up.isAdmin && !up.isSysAdmin) {
        final adminBarangay = up.user?.barangay.name;
        if (adminBarangay != null && adminBarangay.isNotEmpty) {
          reports = reports
              .where((r) => (r.barangay.toString()) == adminBarangay)
              .toList();
        }
      }

      // Aggregate per-barangay counts
      final Map<String, Map<String, int>> agg = {};
      for (final r in reports) {
        final String b = (r.barangay.toString()).trim();
        final bucket = agg.putIfAbsent(
          b,
          () => {'total': 0, 'verified': 0, 'resolved': 0, 'flagged': 0},
        );
        bucket['total'] = (bucket['total'] ?? 0) + 1;
        final status = r.status;
        if (status == ReportStatus.verified) {
          bucket['verified'] = (bucket['verified'] ?? 0) + 1;
        } else if (status == ReportStatus.resolved) {
          bucket['resolved'] = (bucket['resolved'] ?? 0) + 1;
        } else if (status == ReportStatus.flagged) {
          bucket['flagged'] = (bucket['flagged'] ?? 0) + 1;
        }
        // pending is implicit (total - others)
      }

      final stats = agg.entries.map((e) {
        final m = e.value;
        return BarangayReportStat(
          barangay: e.key,
          total: m['total'] ?? 0,
          verified: m['verified'] ?? 0,
          resolved: m['resolved'] ?? 0,
          flagged: m['flagged'] ?? 0,
        );
      }).toList()..sort((a, b) => b.total.compareTo(a.total));

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (c) => BarangayReportStats(
            stats: stats,
            timestamp: DateTime.now(),
            topLimit: 50,
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Failed to build per-barangay report stats: $e\n$st');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load per-barangay report stats'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPerBarangayLoading = false);
    }
  }

  // Export admin's barangay user stats to Google Sheets
  Future<void> _exportAdminUserStats() async {
    final up = Provider.of<UserProvider>(context, listen: false);
    final adminBarangay = up.user?.barangay.name;
    if (adminBarangay == null || adminBarangay.isEmpty) {
      SnackbarUtils.show(context, 'Admin barangay not available');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Exporting...'),
    );
    try {
      final stats = await AccountService.instance.getUserStatsPerBarangay(
        includeZeroEntries: true,
      );
      final match = stats.firstWhere(
        (s) => s.barangay.trim() == adminBarangay.trim(),
        orElse: () => BarangayUserStat(
          barangay: adminBarangay,
          total: 0,
          verified: 0,
          unverified: 0,
        ),
      );
      final resp = await GoogleSheetsService.instance.exportBarangayStat(match);
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      final url = (resp['url'] is String) ? resp['url'] as String : '';
      SnackbarUtils.show(
        context,
        url.isNotEmpty ? 'Exported $adminBarangay' : 'Export completed',
        action: url.isNotEmpty
            ? SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () => launchUrlString(url),
              )
            : null,
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      SnackbarUtils.show(context, 'Export failed: $e', icon: Icons.error);
    }
  }

  // Export admin's barangay report stats to Google Sheets
  Future<void> _exportAdminReportStats() async {
    final up = Provider.of<UserProvider>(context, listen: false);
    final rp = Provider.of<ReportProvider>(context, listen: false);
    final adminBarangay = up.user?.barangay.name;
    if (adminBarangay == null || adminBarangay.isEmpty) {
      SnackbarUtils.show(context, 'Admin barangay not available');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Exporting...'),
    );

    try {
      var reports = rp.allReports;
      reports = reports
          .where((r) => (r.barangay.toString()).trim() == adminBarangay.trim())
          .toList();

      int total = 0, verified = 0, resolved = 0, flagged = 0;
      for (final r in reports) {
        total++;
        final status = r.status;
        if (status == ReportStatus.verified) verified++;
        if (status == ReportStatus.resolved) resolved++;
        if (status == ReportStatus.flagged) flagged++;
      }

      final resp = await GoogleSheetsService.instance.exportBarangayReportStat(
        barangay: adminBarangay,
        total: total,
        verified: verified,
        resolved: resolved,
        flagged: flagged,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final url = (resp['url'] is String) ? resp['url'] as String : '';
      SnackbarUtils.show(
        context,
        url.isNotEmpty ? 'Exported $adminBarangay' : 'Export completed',
        action: url.isNotEmpty
            ? SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () => launchUrlString(url),
              )
            : null,
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      SnackbarUtils.show(context, 'Export failed: $e', icon: Icons.error);
    }
  }

  Widget _buildDesktopDashboard(
    ResponsiveInfo info,
    DateTime now, {
    required bool showPerBarangayButtons,
    required bool isAdminViewing,
  }) {
    return SizedBox(
      width: info.scale(380),
      height: double.infinity,
      child: MouseRegion(
        onEnter: (_) {
          if (!_isPointerOverDashboard) {
            setState(() => _isPointerOverDashboard = true);
          }
        },
        onExit: (_) {
          if (_isPointerOverDashboard) {
            setState(() => _isPointerOverDashboard = false);
          }
        },
        child: Container(
          color: Colors.grey.shade100,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: (event) {},
            child: SingleChildScrollView(
              controller: _dashboardScrollController,
              padding: EdgeInsets.all(info.scale(16)),
              child: Column(
                children: [
                  SizedBox(height: info.scale(16)),
                  if (_userStatsError != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _userStatsError!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  UserStats(
                    title: 'Total Users',
                    totalCount: _userStats?['total'] ?? 0,
                    verifiedCount: _userStats?['verified'] ?? 0,
                    unverifiedCount: _userStats?['unverified'] ?? 0,
                    timestamp: now,
                    onBarangayTap: showPerBarangayButtons
                        ? _showPerBarangayStats
                        : null,
                    // Admins get export for their barangay
                    onExportBarangay:
                        (!showPerBarangayButtons && isAdminViewing)
                        ? _exportAdminUserStats
                        : null,
                  ),
                  SizedBox(height: info.scale(16)),
                  ReportStats(
                    reportCounts: _reportCounts,
                    timestamp: now,
                    onBarangayTap: showPerBarangayButtons
                        ? _showPerBarangayReportStats
                        : null,
                    onExportBarangay:
                        (!showPerBarangayButtons && isAdminViewing)
                        ? _exportAdminReportStats
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDashboard(
    ResponsiveInfo info,
    DateTime now, {
    required bool showPerBarangayButtons,
    required bool isAdminViewing,
  }) {
    return DraggableScrollableSheet(
      controller: _dashboardSheetController,
      initialChildSize: 0.4,
      minChildSize: 0.08,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.08, 0.4, 1.0],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(info.scale(16)),
            child: Column(
              children: [
                Container(
                  width: info.scale(40),
                  height: info.scale(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: info.scale(16)),
                if (_userStatsError != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _userStatsError!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                UserStats(
                  title: 'Total Users',
                  totalCount: _userStats?['total'] ?? 0,
                  verifiedCount: _userStats?['verified'] ?? 0,
                  unverifiedCount: _userStats?['unverified'] ?? 0,
                  timestamp: now,
                  onBarangayTap: showPerBarangayButtons
                      ? _showPerBarangayStats
                      : null,
                  onExportBarangay: (!showPerBarangayButtons && isAdminViewing)
                      ? _exportAdminUserStats
                      : null,
                ),
                SizedBox(height: info.scale(16)),
                ReportStats(
                  reportCounts: _reportCounts,
                  timestamp: now,
                  onBarangayTap: showPerBarangayButtons
                      ? _showPerBarangayReportStats
                      : null,
                  onExportBarangay: (!showPerBarangayButtons && isAdminViewing)
                      ? _exportAdminReportStats
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _computeMapControlsBottom(ResponsiveInfo info, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    if (!_isSysAdmin) {
      return info.scale(16) + paddingBottom;
    }

    double baseBottom;
    if (info.isMobile) {
      final fraction =
          (_dashboardSheetFraction <= 0 || _dashboardSheetFraction > 1)
          ? 0.4
          : (_dashboardSheetFraction < 0.4 ? _dashboardSheetFraction : 0.4);
      baseBottom = screenHeight * fraction + info.scale(16);
    } else {
      baseBottom = info.scale(16);
    }

    final minBottom = info.scale(8) + paddingBottom;
    final maxBottom = screenHeight * 0.6;
    final result = (baseBottom + paddingBottom).clamp(minBottom, maxBottom);
    return result;
  }
}
