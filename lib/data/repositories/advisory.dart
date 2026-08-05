import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:vcroad/data/models/advisory.dart';
import 'dart:convert';
import 'package:vcroad/data/repositories/barangay.dart';

class AdvisoryService {
  static final AdvisoryService _instance = AdvisoryService._internal();
  factory AdvisoryService() => _instance;
  AdvisoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BarangayService _barangayService = BarangayService(); // ✅ ADD THIS

  static const String _collection = 'advisories';

  // OSRM base URL for snap-to-road (free, no API key required)
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/nearest/v1/driving';

  /// Get single advisory by ID
  Future<Advisory?> getAdvisoryById(String advisoryId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(advisoryId)
          .get();

      if (!doc.exists) return null;

      return Advisory.fromJson(doc.data()!, advisoryId: doc.id);
    } catch (e) {
      debugPrint('❌ Error fetching advisory $advisoryId: $e');
      return null;
    }
  }

  /// Generate a Firestore document identifier without writing. Callers can
  /// use it to upload media keyed by the advisory id before the doc exists.
  String generateAdvisoryId() => _firestore.collection(_collection).doc().id;

  /// Create new advisory
  Future<String> createAdvisory(Advisory advisory) async {
    try {
      // Validate required fields
      _validateAdvisory(advisory);

      // Use a pre-generated id when provided (so callers can upload media
      // against the id before the doc write); otherwise generate one here.
      final docRef = advisory.advisoryId.isNotEmpty
          ? _firestore.collection(_collection).doc(advisory.advisoryId)
          : _firestore.collection(_collection).doc();
      final uid = _currentUid();
      final now = DateTime.now();

      // Prepare payload and ensure recurring advisories do NOT persist
      // one-time start/end timestamps (set them to null).
      final payload = advisory.copyWith(
        advisoryId: docRef.id,
        createdByUid: uid,
        updatedByUid: uid,
        statusUpdatedAt: now,
        searchKeywords: advisory.buildSearchKeywords(),
        nextStatusAt: Advisory.computeNextStatusAt(
          status: advisory.status,
          scheduleType: advisory.scheduleType,
          startDate: advisory.startDate,
          endDate: advisory.endDate,
          weekdays: advisory.weekdays,
          recurringStartTime: advisory.recurringStartTime,
          recurringEndTime: advisory.recurringEndTime,
          now: now,
        ),
        barangayId: advisory.barangayId ?? await resolveBarangayId(advisory.barangay),
      ).toJson();

      if (advisory.scheduleType == AdvisoryScheduleType.recurring) {
        payload['startDate'] = null;
        payload['endDate'] = null;
      }

      await docRef.set(payload);

      debugPrint('✅ Advisory created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating advisory: $e');
      rethrow;
    }
  }

  /// Update existing advisory (transactional optimistic lock).
  Future<void> updateAdvisory(Advisory advisory) async {
    try {
      _validateAdvisory(advisory);

      final ref = _firestore.collection(_collection).doc(advisory.advisoryId);
      final uid = _currentUid();
      final now = DateTime.now();

      // Resolve enrichments OUTSIDE the transaction (asset/network I/O is not
      // allowed inside Firestore transactions).
      final String? resolvedBarangayId = advisory.barangayId ??
          (await resolveBarangayId(advisory.barangay));
      final keywords = advisory.buildSearchKeywords();
      final nextStatusAt = Advisory.computeNextStatusAt(
        status: advisory.status,
        scheduleType: advisory.scheduleType,
        startDate: advisory.startDate,
        endDate: advisory.endDate,
        weekdays: advisory.weekdays,
        recurringStartTime: advisory.recurringStartTime,
        recurringEndTime: advisory.recurringEndTime,
        now: now,
      );

      await _firestore.runTransaction((txn) async {
        final currentDoc = await txn.get(ref);

        if (!currentDoc.exists) {
          throw Exception('Advisory not found');
        }

        final currentData = currentDoc.data()!;
        final currentVersion = currentData['version'] ?? 1;
        if (currentVersion != advisory.version) {
          throw Exception(
            'Advisory was modified by another user. Please refresh and try again.',
          );
        }

        final statusChanged =
            (currentData['status'] as String?) != advisory.status.name;

        // Increment version
        final updatedAdvisory = advisory.copyWith(
          version: currentVersion + 1,
          updatedAt: now,
          updatedByUid: uid,
          // preserve immutable/audit fields from the stored document
          advisoryId: ref.id,
          createdAt: _parseDate(currentData['createdAt']),
          createdBy: (currentData['createdBy'] as String?) ?? advisory.createdBy,
          createdByUid:
              (currentData['createdByUid'] as String?) ?? advisory.createdByUid,
          statusUpdatedAt: statusChanged
              ? now
              : _parseNullableDate(currentData['statusUpdatedAt']),
          searchKeywords: keywords,
          nextStatusAt: nextStatusAt,
          barangayId: resolvedBarangayId ?? currentData['barangayId'] as String?,
        );

        // Append to capped version history (audit trail, max 10 entries).
        final history = _parseHistory(currentData['versionHistory']);
        history.insert(
          0,
          AdvisoryHistory(
            version: currentVersion + 1,
            updatedBy: uid,
            updatedAt: now,
            changedFields: _changedFields(currentData, updatedAdvisory),
          ),
        );
        if (history.length > 10) history.removeRange(10, history.length);

        // Build payload and null-out one-time fields for recurring advisories.
        final payload = updatedAdvisory.toJson();
        payload['versionHistory'] = history.map((h) => h.toJson()).toList();
        if (updatedAdvisory.scheduleType == AdvisoryScheduleType.recurring) {
          payload['startDate'] = null;
          payload['endDate'] = null;
        }

        txn.update(ref, payload);
      });
    } catch (e) {
      debugPrint('❌ Error updating advisory: $e');
      rethrow;
    }
  }

  /// Resolve a stable `barangayId` from a barangay display name using the
  /// bundled BarangayService (GeoJSON `id`). Returns null if unresolvable.
  Future<String?> resolveBarangayId(String barangayName) async {
    if (barangayName.isEmpty) return null;
    try {
      if (!_barangayService.isLoaded) {
        await _barangayService.loadBarangays();
      }
      for (final b in _barangayService.barangays) {
        if (b.name == barangayName && b.id != null) return b.id;
      }
      // fall back to a normalized comparison
      final normalized = barangayName.toLowerCase();
      for (final b in _barangayService.barangays) {
        if (b.name.toLowerCase() == normalized && b.id != null) return b.id;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Could not resolve barangayId for "$barangayName": $e');
      return null;
    }
  }

  static String? _currentUid() =>
      FirebaseAuth.instance.currentUser?.uid;

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static List<AdvisoryHistory> _parseHistory(dynamic raw) {
    if (raw == null) return [];
    final list = raw as List;
    return list
        .map((e) => AdvisoryHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<String>? _changedFields(
    Map<String, dynamic> before,
    Advisory after,
  ) {
    final changed = <String>[];
    final fields = {
      'reason': (Advisory a) => a.reason,
      'barangay': (Advisory a) => a.barangay,
      'status': (Advisory a) => a.status.name,
      'placeName': (Advisory a) => a.placeName,
      'contractor': (Advisory a) => a.contractor,
      'contractorContact': (Advisory a) => a.contractorContact,
    };
    for (final entry in fields.entries) {
      final newValue = entry.value(after);
      final oldValue = before[entry.key];
      if ((oldValue ?? '').toString() != (newValue ?? '').toString()) {
        changed.add(entry.key);
      }
    }
    return changed.isEmpty ? null : changed;
  }

  /// Delete advisory
  Future<void> deleteAdvisory(String advisoryId) async {
    try {
      await _firestore.collection(_collection).doc(advisoryId).delete();

      debugPrint('✅ Advisory deleted: $advisoryId');
    } catch (e) {
      debugPrint('❌ Error deleting advisory: $e');
      rethrow;
    }
  }

  /// Snap polyline points to roads using OSRM Nearest API (free, no API key).
  Future<List<LatLng>> snapToRoad(
    List<LatLng> points, {
    bool verbose = false,
  }) async {
    try {
      if (points.isEmpty) return [];
      if (points.length > 100) {
        return await _snapToRoadsChunked(points);
      }
      return await _snapPointsParallel(points);
    } catch (_) {
      return points; // graceful fallback
    }
  }

  /// Snap multiple points to roads via OSRM Nearest (parallel batches of 10).
  Future<List<LatLng>> _snapPointsParallel(List<LatLng> points) async {
    final results = List<LatLng?>.filled(points.length, null);
    const int batchSize = 10;

    for (int i = 0; i < points.length; i += batchSize) {
      final end = min(i + batchSize, points.length);
      final batch = points.sublist(i, end);
      final batchResults = await Future.wait(
        batch.map((p) => _snapPoint(p)).toList(),
      );
      for (int j = 0; j < batchResults.length; j++) {
        results[i + j] = batchResults[j];
      }
    }

    if (results.every((r) => r == null)) return points;
    // Keep original points where snapping failed (never fall back to (0,0)).
    return List.generate(
      points.length,
      (i) => results[i] ?? points[i],
    );
  }

  /// Snap a single point to nearest road via OSRM Nearest.
  /// Returns null on failure (caller falls back to original point).
  Future<LatLng?> _snapPoint(LatLng point, {int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final url =
            '$_osrmBaseUrl/${point.longitude},${point.latitude}';
        final response = await http
            .get(
              Uri.parse(url),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['code'] != 'Ok') continue;

        final waypoints = data['waypoints'] as List<dynamic>?;
        if (waypoints == null || waypoints.isEmpty) continue;

        final loc = waypoints[0]['location'] as List<dynamic>;
        return LatLng(
          (loc[1] as num).toDouble(),
          (loc[0] as num).toDouble(),
        );
      } catch (_) {
        if (attempt == maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return null;
  }

  /// Snap large polylines by chunking
  Future<List<LatLng>> _snapToRoadsChunked(List<LatLng> points) async {
    const chunkSize = 100;
    final List<LatLng> allSnapped = [];

    for (int i = 0; i < points.length; i += chunkSize) {
      final end = (i + chunkSize < points.length)
          ? i + chunkSize
          : points.length;
      final chunk = points.sublist(i, end);
      final snapped = await snapToRoad(chunk); // ✅ UPDATED CALL
      allSnapped.addAll(snapped);
    }

    return allSnapped;
  }

  /// Detect barangay from a geographic point using polygon matching
  Future<String?> detectBarangay(LatLng point) async {
    try {
      // Ensure barangay data is loaded
      if (!_barangayService.isLoaded) {
        await _barangayService.loadBarangays();
      }

      // Use barangay service's optimized matching
      final matchedBarangay = _barangayService.matchFromLatLng(point);

      if (matchedBarangay != null) {
        debugPrint('✅ Detected barangay: ${matchedBarangay.name}');
        return matchedBarangay.name;
      }

      debugPrint('⚠️ Point not within any barangay boundaries');
      return null;
    } catch (e) {
      debugPrint('❌ Error detecting barangay: $e');
      return null;
    }
  }

  /// Validate advisory before saving
  void _validateAdvisory(Advisory advisory) {
    if (advisory.advisoryType.isEmpty) {
      throw Exception('Advisory type is required');
    }

    if (advisory.reason.isEmpty) {
      throw Exception('Reason is required');
    }

    if (advisory.barangay.isEmpty) {
      throw Exception('Barangay is required');
    }

    // Validate start/end only for one-time advisories. Recurring advisories
    // persist startDate/endDate=null.
    if (advisory.scheduleType == AdvisoryScheduleType.oneTime) {
      if (advisory.startDate.isAfter(advisory.endDate)) {
        throw Exception('Start date must be before end date');
      }
    }

    // Validate construction advisories
    final category = AdvisoryCategory.findById(advisory.advisoryType);
    if (category?.requiresContractor == true) {
      if (advisory.contractor == null || advisory.contractor!.isEmpty) {
        throw Exception(
          'Contractor name is required for construction advisories',
        );
      }
    }

    // Validate recurring schedules
    if (advisory.scheduleType == AdvisoryScheduleType.recurring) {
      if (advisory.weekdays == null || advisory.weekdays!.isEmpty) {
        throw Exception('Weekdays are required for recurring advisories');
      }
      if (advisory.recurringStartTime == null ||
          advisory.recurringEndTime == null) {
        throw Exception(
          'Start and end times are required for recurring advisories',
        );
      }

      // Ensure times are not identical (degenerate range). We allow end < start
      // because that represents wrap-around (e.g. 22:00 -> 02:00).
      final int startMinutes =
          advisory.recurringStartTime!.hour * 60 +
          advisory.recurringStartTime!.minute;
      final int endMinutes =
          advisory.recurringEndTime!.hour * 60 +
          advisory.recurringEndTime!.minute;

      if (startMinutes == endMinutes) {
        throw Exception('Recurring end time must be different from start time');
      }
    }

    // Validate routes
    if (advisory.affectedRoads == null || advisory.affectedRoads!.isEmpty) {
      throw Exception('Affected roads are required');
    }
  }

  /// Get advisories count by status
  Future<Map<AdvisoryStatus, int>> getAdvisoryCountsByStatus({
    String? barangay,
    String? barangayId,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (barangayId != null && barangayId.isNotEmpty) {
        query = query.where('barangayId', isEqualTo: barangayId);
      } else if (barangay != null) {
        query = query.where('barangay', isEqualTo: barangay);
      }

      final snapshot = await query.get();

      final counts = <AdvisoryStatus, int>{
        AdvisoryStatus.active: 0,
        AdvisoryStatus.inactive: 0,
        AdvisoryStatus.scheduled: 0,
        AdvisoryStatus.expired: 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final statusStr = (data['status'] as String?) ?? 'active';
        final status = AdvisoryStatus.values.firstWhere(
          (s) => s.name == statusStr,
          orElse: () => AdvisoryStatus.active,
        );
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      debugPrint('❌ Error getting advisory counts: $e');
      if (kDebugMode) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('index')) {
          debugPrint(
            '[Firestore][getAdvisoryCountsByStatus] Consider adding composite index for barangay + createdAt or status queries.',
          );
        }
        if (msg.contains('credentials_missing') ||
            msg.contains('unauthenticated')) {
          debugPrint(
            '[Firestore][getAdvisoryCountsByStatus] Auth issue detected: ensure Firebase credentials.',
          );
        }
      }
      return {};
    }
  }

  /// Clear all data (for testing)
  Future<void> clearAllAdvisories() async {
    if (kDebugMode) {
      final snapshot = await _firestore.collection(_collection).get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Cleared all advisories');
    }
  }

  /// Watch advisories in realtime. Use optional barangay and status filters.
  /// Useful for UI lists so changes are pushed incrementally.
  Stream<List<Advisory>> watchAdvisories({
    String? barangay,
    String? barangayId,
    List<AdvisoryStatus>? statuses,
    int? limit,
  }) {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true);

      if (barangayId != null && barangayId.isNotEmpty) {
        query = query.where('barangayId', isEqualTo: barangayId);
      } else if (barangay != null && barangay.isNotEmpty) {
        query = query.where('barangay', isEqualTo: barangay);
      }

      if (statuses != null && statuses.isNotEmpty) {
        // Firestore whereIn supports up to 10 items; statuses list is small.
        final statusNames = statuses.map((s) => s.name).toList();
        query = query.where('status', whereIn: statusNames);
      }

      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }

      return query
          .snapshots()
          .handleError((error) {
            if (kDebugMode) {
              if (error is FirebaseException) {
                debugPrint(
                  '[Firestore][watchAdvisories] FirebaseException code=${error.code} message=${error.message}',
                );
              } else {
                debugPrint('[Firestore][watchAdvisories] Stream error: $error');
              }
              final msg = error.toString().toLowerCase();
              if (msg.contains('index')) {
                debugPrint(
                  '[Firestore][watchAdvisories] Missing index for barangay/status/orderBy query — add composite index.',
                );
              }
              if (msg.contains('credentials_missing') ||
                  msg.contains('unauthenticated')) {
                debugPrint(
                  '[Firestore][watchAdvisories] Auth error: verify Firebase credentials and project access.',
                );
              }
            }
          }, test: (_) => true)
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Advisory.fromJson(doc.data(), advisoryId: doc.id))
                .toList();
          });
    } catch (e) {
      debugPrint(
        '[AdvisoryService][watchAdvisories] Exception building stream: $e',
      );
      return Stream.value(<Advisory>[]);
    }
  }
}
