import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ added

enum AdvisoryScheduleType { oneTime, recurring }

enum AdvisoryStatus {
  active,
  inactive,
  expired,
  scheduled;

  String get label => switch (this) {
        AdvisoryStatus.active => 'Active',
        AdvisoryStatus.inactive => 'Inactive',
        AdvisoryStatus.expired => 'Expired',
        AdvisoryStatus.scheduled => 'Scheduled',
      };

  Color get color => switch (this) {
        AdvisoryStatus.active => const Color(0xFF2E7D32), // green
        AdvisoryStatus.inactive => const Color(0xFF757575), // grey
        AdvisoryStatus.expired => const Color(0xFF616161), // dark grey
        AdvisoryStatus.scheduled => const Color(0xFFF57C00), // orange
      };
}

const List<AdvisoryCategory> advisoryCategories = [
  AdvisoryCategory(
    id: 'road_closure',
    title: 'Road Closure',
    iconPath: 'assets/icons/road_closure.webp',
    markerIconPath: 'assets/icons/road_closure.webp',
    color: Color(0xFFD32F2F), // Red
    icon: Icons.block,
  ),
  AdvisoryCategory(
    id: 'stop_and_go',
    title: 'Stop-and-Go',
    iconPath: 'assets/icons/stop_and_go.webp',
    markerIconPath: 'assets/icons/stop_and_go.webp',
    color: Color(0xFFFFA726), // Orange
    icon: Icons.traffic,
  ),
  AdvisoryCategory(
    id: 'one_way',
    title: 'One-Way',
    iconPath: 'assets/icons/one_way.webp',
    markerIconPath: 'assets/icons/one_way.webp',
    color: Color(0xFF1976D2), // Blue
    icon: Icons.arrow_forward,
  ),
  AdvisoryCategory(
    id: 'construction',
    title: 'Road Work / Construction',
    iconPath: 'assets/icons/road_construction.webp',
    markerIconPath: 'assets/icons/road_construction.webp',
    color: Color(0xFFF57C00), // Deep Orange
    requiresContractor: true,
    icon: Icons.construction,
  ),
  AdvisoryCategory(
    id: 'partial_lane',
    title: 'Partial Lane Closure',
    iconPath: 'assets/icons/partial_lane.webp',
    markerIconPath: 'assets/icons/partial_lane.webp',
    color: Color(0xFFFDD835), // Yellow
    icon: Icons.remove_road,
  ),
  AdvisoryCategory(
    id: 'event',
    title: 'Event-Related Advisory',
    iconPath: 'assets/icons/event.webp',
    markerIconPath: 'assets/icons/event.webp',
    color: Color(0xFF7B1FA2), // Purple
    icon: Icons.event,
  ),
];

class Advisory {
  final String advisoryId;
  final String advisoryType;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String barangay;
  final String? barangayId;
  final AdvisoryScheduleType scheduleType;
  final List<int>? weekdays;
  final TimeOfDay? recurringStartTime;
  final TimeOfDay? recurringEndTime;
  final List<List<LatLng>>? affectedRoads;
  final List<List<LatLng>>? alternateRoutes;
  final LatLng? center;
  final LatLng? boundsNE;
  final LatLng? boundsSW;
  final String? contractor;
  final String? contractorContact;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;
  final String? createdByUid;
  final String? updatedByUid;
  final AdvisoryStatus status;
  final String? imageUrl;
  final String? placeName;
  final int version; // For optimistic locking
  final List<String>? searchKeywords;
  final DateTime? nextStatusAt;
  final DateTime? statusUpdatedAt;
  final List<AdvisoryHistory>? versionHistory;

  const Advisory({
    required this.advisoryId,
    required this.advisoryType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.barangay,
    required this.scheduleType,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.status,
    this.barangayId,
    this.weekdays,
    this.recurringStartTime,
    this.recurringEndTime,
    this.affectedRoads,
    this.alternateRoutes,
    this.center,
    this.boundsNE,
    this.boundsSW,
    this.contractor,
    this.contractorContact,
    this.updatedBy,
    this.createdByUid,
    this.updatedByUid,
    this.imageUrl,
    this.placeName,
    this.version = 1,
    this.searchKeywords,
    this.nextStatusAt,
    this.statusUpdatedAt,
    this.versionHistory,
  });

  Advisory copyWith({
    String? advisoryId,
    String? advisoryType,
    String? reason,
    DateTime? startDate,
    DateTime? endDate,
    String? barangay,
    String? barangayId,
    AdvisoryScheduleType? scheduleType,
    List<int>? weekdays,
    TimeOfDay? recurringStartTime,
    TimeOfDay? recurringEndTime,
    List<List<LatLng>>? affectedRoads,
    List<List<LatLng>>? alternateRoutes,
    LatLng? center,
    LatLng? boundsNE,
    LatLng? boundsSW,
    String? contractor,
    String? contractorContact,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? createdByUid,
    String? updatedByUid,
    AdvisoryStatus? status,
    String? imageUrl,
    String? placeName,
    int? version,
    List<String>? searchKeywords,
    DateTime? nextStatusAt,
    DateTime? statusUpdatedAt,
    List<AdvisoryHistory>? versionHistory,
  }) {
    return Advisory(
      advisoryId: advisoryId ?? this.advisoryId,
      advisoryType: advisoryType ?? this.advisoryType,
      reason: reason ?? this.reason,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      barangay: barangay ?? this.barangay,
      barangayId: barangayId ?? this.barangayId,
      scheduleType: scheduleType ?? this.scheduleType,
      weekdays: weekdays ?? this.weekdays,
      recurringStartTime: recurringStartTime ?? this.recurringStartTime,
      recurringEndTime: recurringEndTime ?? this.recurringEndTime,
      affectedRoads: affectedRoads ?? this.affectedRoads,
      alternateRoutes: alternateRoutes ?? this.alternateRoutes,
      center: center ?? this.center,
      boundsNE: boundsNE ?? this.boundsNE,
      boundsSW: boundsSW ?? this.boundsSW,
      contractor: contractor ?? this.contractor,
      contractorContact: contractorContact ?? this.contractorContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      placeName: placeName ?? this.placeName,
      version: version ?? this.version,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      nextStatusAt: nextStatusAt ?? this.nextStatusAt,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      versionHistory: versionHistory ?? this.versionHistory,
    );
  }

  /// Compute center of affected roads
  static LatLng? computeCenter(List<List<LatLng>>? polylines) {
    if (polylines == null || polylines.isEmpty) return null;

    double latSum = 0;
    double lngSum = 0;
    int count = 0;

    for (final poly in polylines) {
      for (final point in poly) {
        latSum += point.latitude;
        lngSum += point.longitude;
        count++;
      }
    }

    return count > 0 ? LatLng(latSum / count, lngSum / count) : null;
  }

  /// Compute the north-east / south-west bounding box of the given polylines.
  /// Returns a record `(northeast, southwest)` or null when empty.
  static ({LatLng northeast, LatLng southwest})? computeBounds(
    List<List<LatLng>>? polylines,
  ) {
    if (polylines == null || polylines.isEmpty) return null;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final poly in polylines) {
      for (final point in poly) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
    }

    if (minLat == double.infinity) return null;
    return (
      northeast: LatLng(maxLat, maxLng),
      southwest: LatLng(minLat, minLng),
    );
  }

  /// Compute when `status` should next auto-transition, or null when there is
  /// no scheduled change. Stored as `nextStatusAt` to make the (currently
  /// deferred) status lifecycle tractable for a future scheduler / evaluator.
  static DateTime? computeNextStatusAt({
    required AdvisoryStatus status,
    required AdvisoryScheduleType scheduleType,
    required DateTime startDate,
    required DateTime endDate,
    List<int>? weekdays,
    TimeOfDay? recurringStartTime,
    TimeOfDay? recurringEndTime,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();

    if (scheduleType == AdvisoryScheduleType.oneTime) {
      switch (status) {
        case AdvisoryStatus.scheduled:
          return startDate.isAfter(reference) ? startDate : null;
        case AdvisoryStatus.active:
          return endDate.isAfter(reference) ? endDate : null;
        case AdvisoryStatus.expired:
        case AdvisoryStatus.inactive:
          return null;
      }
    }

    // Recurring: the next window start (when scheduled) or window end (when
    // active). Scan the next 8 days for the earliest boundary after `now`.
    final selected = (weekdays == null || weekdays.isEmpty)
        ? <int>{DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday, DateTime.saturday, DateTime.sunday}
        : weekdays.toSet();

    DateTime? earliest;
    for (int offset = 0; offset < 8; offset++) {
      final day = reference.add(Duration(days: offset));
      if (!selected.contains(day.weekday)) continue;

      if (recurringStartTime == null || recurringEndTime == null) {
        // Whole-day window: boundary is the next midnight.
        final boundary = DateTime(day.year, day.month, day.day);
        if (boundary.isAfter(reference) && (earliest == null || boundary.isBefore(earliest))) {
          earliest = boundary;
        }
        continue;
      }

      DateTime start = DateTime(
        day.year,
        day.month,
        day.day,
        recurringStartTime.hour,
        recurringStartTime.minute,
      );
      DateTime end = DateTime(
        day.year,
        day.month,
        day.day,
        recurringEndTime.hour,
        recurringEndTime.minute,
      );
      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1)); // wrap-around window
      }

      if (start.isAfter(reference) && status == AdvisoryStatus.scheduled) {
        earliest = _minOrNull(earliest, start);
      }
      if (status == AdvisoryStatus.active) {
        final boundary = end.isAfter(reference) ? end : start;
        if (boundary.isAfter(reference)) earliest = _minOrNull(earliest, boundary);
      }
    }
    return earliest;
  }

  static DateTime? _minOrNull(DateTime? a, DateTime b) =>
      a == null || b.isBefore(a) ? b : a;

  /// Denormalized lowercase search tokens for indexed (`array-contains`) search.
  List<String> buildSearchKeywords() {
    final tokens = <String>[];
    void add(String? value) {
      final v = value?.trim().toLowerCase();
      if (v != null && v.isNotEmpty) tokens.add(v);
    }

    add(barangay);
    add(placeName);
    add(reason);
    final category = AdvisoryCategory.findById(advisoryType);
    add(category?.title);
    add(contractor);
    return tokens.toSet().toList();
  }

  /// Firestore-safe JSON serialization
  Map<String, dynamic> toJson() => {
        'advisoryId': advisoryId,
        'advisoryType': advisoryType,
        'reason': reason,
        // store as Firestore Timestamps for correct querying and indexing
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'barangay': barangay,
        'barangayId': barangayId,
        'scheduleType': scheduleType.name,
        'weekdays': weekdays,
        'recurringStartTime': recurringStartTime != null
            ? {
                'hour': recurringStartTime!.hour,
                'minute': recurringStartTime!.minute,
              }
            : null,
        'recurringEndTime': recurringEndTime != null
            ? {'hour': recurringEndTime!.hour, 'minute': recurringEndTime!.minute}
            : null,
        'affectedRoads': affectedRoads
            ?.asMap()
            .entries
            .map(
              (e) => {
                'polylineIndex': e.key,
                'points': e.value
                    .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                    .toList(),
              },
            )
            .toList(),
        'alternateRoutes': alternateRoutes
            ?.asMap()
            .entries
            .map(
              (e) => {
                'polylineIndex': e.key,
                'points': e.value
                    .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                    .toList(),
              },
            )
            .toList(),
        // Store as Firestore GeoPoints so center/bounds are geo-queryable.
        'center': center != null
            ? GeoPoint(center!.latitude, center!.longitude)
            : null,
        'boundsNE': boundsNE != null
            ? GeoPoint(boundsNE!.latitude, boundsNE!.longitude)
            : null,
        'boundsSW': boundsSW != null
            ? GeoPoint(boundsSW!.latitude, boundsSW!.longitude)
            : null,
        'contractor': contractor,
        'contractorContact': contractorContact,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdByUid': createdByUid,
        'updatedByUid': updatedByUid,
        'status': status.name,
        'imageUrl': imageUrl,
        'placeName': placeName,
        'version': version,
        'searchKeywords': searchKeywords,
        'nextStatusAt':
            nextStatusAt != null ? Timestamp.fromDate(nextStatusAt!) : null,
        'statusUpdatedAt': statusUpdatedAt != null
            ? Timestamp.fromDate(statusUpdatedAt!)
            : null,
        'versionHistory':
            versionHistory?.map((h) => h.toJson()).toList(),
      };

  /// Reconstruct from Firestore JSON
  factory Advisory.fromJson(Map<String, dynamic> json, {String? advisoryId}) {
    List<List<LatLng>>? parsePolylines(dynamic data) {
      if (data == null) return null;
      return (data as List)
          .map(
            (obj) => (obj['points'] as List)
                .map((p) => LatLng(p['lat'], p['lng']))
                .toList(),
          )
          .toList();
    }

    LatLng? center;
    if (json['center'] != null) {
      center = _parseLatLng(json['center']);
    }

    // helper to parse Timestamp or ISO string
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is Map && v['_seconds'] != null) {
        // Firestore object form
        final seconds = v['_seconds'] as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is Map && v['_seconds'] != null) {
        final seconds = v['_seconds'] as int;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final parsedBounds = Advisory.computeBounds(parsePolylines(json['affectedRoads']));
    final LatLng? parsedCenter = parsedBounds != null
        ? LatLng(
            (parsedBounds.northeast.latitude + parsedBounds.southwest.latitude) / 2,
            (parsedBounds.northeast.longitude + parsedBounds.southwest.longitude) / 2,
          )
        : null;

    return Advisory(
      advisoryId: advisoryId ?? json['advisoryId'] ?? '',
      advisoryType: json['advisoryType'] ?? '',
      reason: json['reason'] ?? '',
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      barangay: json['barangay'] ?? '',
      barangayId: json['barangayId'] as String?,
      scheduleType: AdvisoryScheduleType.values.firstWhere(
        (e) => e.name == json['scheduleType'],
        orElse: () => AdvisoryScheduleType.oneTime,
      ),
      weekdays: (json['weekdays'] as List?)?.map((e) => e as int).toList(),
      recurringStartTime: json['recurringStartTime'] != null
          ? TimeOfDay(
              hour: json['recurringStartTime']['hour'],
              minute: json['recurringStartTime']['minute'],
            )
          : null,
      recurringEndTime: json['recurringEndTime'] != null
          ? TimeOfDay(
              hour: json['recurringEndTime']['hour'],
              minute: json['recurringEndTime']['minute'],
            )
          : null,
      affectedRoads: parsePolylines(json['affectedRoads']),
      alternateRoutes: parsePolylines(json['alternateRoutes']),
      center: center ?? parsedCenter,
      boundsNE: _parseLatLng(json['boundsNE']) ?? parsedBounds?.northeast,
      boundsSW: _parseLatLng(json['boundsSW']) ?? parsedBounds?.southwest,
      contractor: json['contractor'],
      contractorContact: json['contractorContact'],
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      createdBy: json['createdBy'] ?? '',
      updatedBy: json['updatedBy'],
      createdByUid: json['createdByUid'] as String?,
      updatedByUid: json['updatedByUid'] as String?,
      status: AdvisoryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AdvisoryStatus.active,
      ),
      imageUrl: json['imageUrl'],
      placeName: json['placeName'],
      version: json['version'] ?? 1,
      searchKeywords: (json['searchKeywords'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      nextStatusAt: parseNullableDate(json['nextStatusAt']),
      statusUpdatedAt: parseNullableDate(json['statusUpdatedAt']),
      versionHistory: (json['versionHistory'] as List?)
          ?.map((h) => AdvisoryHistory.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Parse a lat/lng value that may be a Firestore GeoPoint, a `{lat,lng}` map,
  /// or a `[lng, lat]` list.
  static LatLng? _parseLatLng(dynamic value) {
    if (value == null) return null;
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = value['lat'] ?? value['latitude'];
      final lng = value['lng'] ?? value['lon'] ?? value['longitude'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
      return null;
    }
    if (value is List && value.length >= 2) {
      final lng = value[0];
      final lat = value[1];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }
}

class AdvisoryCategory {
  final String id;
  final String title;
  final String iconPath;
  final String markerIconPath;
  final Color color;
  final IconData icon;
  final bool requiresContractor;

  const AdvisoryCategory({
    required this.id,
    required this.title,
    required this.iconPath,
    required this.markerIconPath,
    required this.color,
    required this.icon,
    this.requiresContractor = false,
  });

  static AdvisoryCategory? findById(String id) {
    try {
      return advisoryCategories.firstWhere((cat) => cat.id == id);
    } catch (_) {
      return null;
    }
  }

  static AdvisoryCategory? findByTitle(String title) {
    try {
      return advisoryCategories.firstWhere((cat) => cat.title == title);
    } catch (_) {
      return null;
    }
  }

  /// Material icon for a category id, falling back to a sensible default for
  /// unknown/legacy ids. Keeps category icons consistent across all surfaces.
  static IconData iconFor(String id) {
    switch (id) {
      case 'emergency':
        return Icons.warning;
      default:
        return findById(id)?.icon ?? Icons.info;
    }
  }
}

/// A single optimistic-lock / audit entry for an advisory update.
/// Stored capped inside the advisory document as `versionHistory`.
class AdvisoryHistory {
  final int version;
  final String? updatedBy;
  final DateTime updatedAt;
  final List<String>? changedFields;

  const AdvisoryHistory({
    required this.version,
    this.updatedBy,
    required this.updatedAt,
    this.changedFields,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        if (updatedBy != null) 'updatedBy': updatedBy,
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (changedFields != null) 'changedFields': changedFields,
      };

  factory AdvisoryHistory.fromJson(Map<String, dynamic> json) {
    DateTime parsed = DateTime.now();
    final v = json['updatedAt'];
    if (v is Timestamp) {
      parsed = v.toDate();
    } else if (v is String) {
      parsed = DateTime.tryParse(v) ?? DateTime.now();
    }
    return AdvisoryHistory(
      version: json['version'] ?? 1,
      updatedBy: json['updatedBy'] as String?,
      updatedAt: parsed,
      changedFields: (json['changedFields'] as List?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
}
