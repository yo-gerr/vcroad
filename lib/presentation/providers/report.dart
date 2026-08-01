import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/data/models/user.dart'; // add this import
import 'package:vcroad/data/repositories/report.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider();

  final _reports = <ReportData>[];
  final _myReports = <ReportData>[];

  List<ReportData> get allReports => List.unmodifiable(_reports);
  List<ReportData> get myReports => List.unmodifiable(_myReports);

  bool isSubmitting = false;
  String? error;

  Stream<List<ReportData>>? _allStream;
  Stream<List<ReportData>>? _mineStream;
  Stream<List<ReportData>>? _mapStream; // dedicated map stream

  StreamSubscription<List<ReportData>>? _allSub;
  StreamSubscription<List<ReportData>>? _mineSub;
  StreamSubscription<List<ReportData>>? _mapSub; // dedicated map subscription

  // Listen to all reports (optionally filtered)
  void listenAllReports({
    ReportStatus? status,
    ReportCategory? category,
    String? barangay,
    bool activeOnly = true,
    int limit = 50,
    bool excludeResolvedAndFlagged = false,
  }) {
    _allSub?.cancel();

    if (excludeResolvedAndFlagged) {
      // Non-admin users: use a service path that excludes resolved/flagged server-side
      _allStream = ReportService.instance.getAllReportsForNonAdmin(
        limit: limit,
        categoryFilter: category,
        barangayFilter: barangay,
        activeOnly: activeOnly,
      );
    } else {
      _allStream = ReportService.instance.getAllReports(
        limit: limit,
        statusFilter: status,
        categoryFilter: category,
        barangayFilter: barangay,
        activeOnly: activeOnly,
      );
    }

    _allSub = _allStream!.listen((items) {
      _reports
        ..clear()
        ..addAll(items);
      notifyListeners();
    });
  }

  // Listen to a user's own reports
  void listenMyReports(
    String userId, {
    bool activeOnly = true,
    int limit = 50,
  }) {
    _mineSub?.cancel();
    _mineStream = ReportService.instance.getUserReports(
      userId,
      activeOnly: activeOnly,
      limit: limit,
    );
    _mineSub = _mineStream!.listen((items) {
      _myReports
        ..clear()
        ..addAll(items);
      notifyListeners();
    });
  }

  // Stream only map-relevant reports (pending + verified, excludes flagged/resolved).
  void listenMapReports({String? barangay, int limit = 300}) {
    // Use a dedicated subscription for the map so other listeners (admin lists)
    // do not cancel the map feed and vice-versa.
    _mapSub?.cancel();
    _mapStream = ReportService.instance.getMapReports(
      barangayFilter: barangay,
      limit: limit,
    );

    // local flag for first event (avoid leading underscore for local identifiers)
    bool firstEvent = true;
    _mapSub = _mapStream!.listen(
      (items) {
        // Debug/log information about incoming reports for map
        if (kDebugMode) {
          debugPrint('[ReportProvider] map stream -> ${items.length} reports');
        }

        _reports
          ..clear()
          ..addAll(items);
        notifyListeners();

        // If first event is empty, probe once (debug) to detect missing isActive field in DB.
        if (firstEvent && kDebugMode && items.isEmpty) {
          firstEvent = false;
          _probeReportsWithoutIsActive(barangay);
        }
      },
      onError: (e, st) {
        if (kDebugMode) {
          debugPrint('[ReportProvider][mapStream] error: $e\n$st');
        }
      },
    );
  }

  // Debug-only helper: run a one-time query without isActive filter to detect documents
  // that would otherwise be excluded by getMapReports (useful for DB schema check).
  Future<void> _probeReportsWithoutIsActive(String? barangay) async {
    try {
      final q = FirebaseFirestore.instance.collection('reports');
      final q2 = (barangay != null && barangay.isNotEmpty)
          ? q.where('barangay', isEqualTo: barangay)
          : q;
      final snap = await q2.limit(20).get();
      if (kDebugMode) {
        debugPrint(
          '[ReportProvider] probe(no isActive) => ${snap.docs.length} docs (sample ids: '
          '${snap.docs.take(5).map((d) => d.id).join(', ')})',
        );
        if (snap.docs.isNotEmpty) {
          debugPrint(
            '[ReportProvider] NOTE: map query used isActive/isResolved/isFlagged filters; '
            'documents exist without that field or with different values. Consider backfilling isActive boolean or removing server-side filter.',
          );
        }
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[ReportProvider] probe error: $e\n$st');
    }
  }

  // Permission gate: only verified and not banned users can submit
  bool canUserReport({required bool isVerified, required bool isBanned}) {
    return isVerified && !isBanned;
  }

  // Submit a report end-to-end (uploads media, creates firestore doc)
  // mediaData: mobile path (String) or bytes (Uint8List)
  // Optional defensive userRole prevents admins from submitting even if UI is bypassed.
  Future<String> submitReport({
    UserRole? userRole,

    // user snapshot fields (explicit to avoid type coupling)
    required String userId,
    required String firstName,
    String? middleName,
    required String lastName,
    String? suffix,
    required String email,
    required String phoneNumber,
    required bool userIsVerified,
    required bool userIsBanned,

    // report inputs
    required ReportCategory category,
    required MediaType mediaType,
    required dynamic mediaData, // String or Uint8List
    required LatLng location,
    required String address,
    required String barangay,
  }) async {
    // Defensive: do not allow admin/sysadmin roles to submit reports even if called programmatically.
    if (userRole != null &&
        (userRole == UserRole.admin || userRole == UserRole.sysadmin)) {
      throw Exception('Admins cannot submit reports.');
    }

    if (!canUserReport(isVerified: userIsVerified, isBanned: userIsBanned)) {
      throw Exception('User not allowed to submit reports.');
    }

    if (mediaData == null) {
      throw Exception('No media attached.');
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      final docRef = FirebaseFirestore.instance.collection('reports').doc();
      final reportId = docRef.id;
      final upload = await ReportService.instance.uploadReportMedia(
        userId: userId, reportId: reportId, mediaType: mediaType,
        mediaData: mediaData is String ? mediaData : (mediaData is Uint8List ? mediaData : null),
      );
      final now = DateTime.now();
      final report = ReportData(
        reportId: reportId, userId: userId, firstName: firstName, middleName: middleName,
        lastName: lastName, suffix: suffix, email: email, phoneNumber: phoneNumber,
        category: category, mediaType: mediaType, mediaPath: upload['mediaPath']!,
        mediaUrl: upload['mediaUrl'], latitude: location.latitude, longitude: location.longitude,
        address: address, barangay: barangay, isVerified: false, isResolved: false, isFlagged: false,
        createdAt: now, updatedAt: now,
      );
      await ReportService.instance.submitReport(report);
      isSubmitting = false;
      notifyListeners();
      return reportId;
    } catch (e) {
      error = e.toString();
      isSubmitting = false;
      notifyListeners();
      rethrow;
    }
  }

  // Confirm/refute interactions (no-ops for own/flagged/resolved)
  Future<void> confirm(ReportData report, String userId) async {
    // Defensive: ensure user is allowed to confirm this report
    if (!report.canUserInteract(userId)) return;

    await ReportService.instance.confirmReport(report.reportId, userId);
  }

  Future<void> refute(ReportData report, String userId) async {
    // Defensive: ensure user is allowed to refute this report
    if (!report.canUserInteract(userId)) return;

    await ReportService.instance.refuteReport(report.reportId, userId);
  }

  // Convenience passthroughs
  Future<void> incrementView(String reportId) =>
      ReportService.instance.incrementViewCount(reportId);

  Future<String?> getMediaUrl(String mediaPath) =>
      ReportService.instance.getDownloadUrl(mediaPath);

  // Admin actions
  Future<void> verify(String reportId, String adminId) =>
      ReportService.instance.verifyReport(reportId, adminId);

  Future<void> resolve(String reportId, String adminId, {String? note}) =>
      ReportService.instance.resolveReport(reportId, adminId, note: note);

  Future<void> flag(String reportId, String adminId, {String? note}) =>
      ReportService.instance.flagReport(reportId, adminId, note: note);

  Future<void> dismissFlag(String reportId, String adminId) =>
      ReportService.instance.dismissFlag(reportId, adminId);

  // New: dismiss verification (undo verify)
  Future<void> dismissVerification(String reportId, String adminId) =>
      ReportService.instance.dismissVerification(reportId, adminId);

  // New: reopen report (undo resolve)
  Future<void> reopen(String reportId, String adminId, {String? note}) =>
      ReportService.instance.reopenReport(reportId, adminId, note: note);

  @override
  void dispose() {
    _allSub?.cancel();
    _mineSub?.cancel();
    _mapSub?.cancel();
    super.dispose();
  }
}
