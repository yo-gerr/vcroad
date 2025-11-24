import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ added

enum AdvisoryScheduleType { oneTime, recurring }

enum AdvisoryStatus { active, inactive, expired, scheduled }

const List<AdvisoryCategory> advisoryCategories = [
  AdvisoryCategory(
    id: 'road_closure',
    title: 'Road Closure',
    iconPath: 'assets/icons/road_closure.webp',
    markerIconPath: 'assets/icons/road_closure.webp',
    color: Color(0xFFD32F2F), // Red
  ),
  AdvisoryCategory(
    id: 'stop_and_go',
    title: 'Stop-and-Go',
    iconPath: 'assets/icons/stop_and_go.webp',
    markerIconPath: 'assets/icons/stop_and_go.webp',
    color: Color(0xFFFFA726), // Orange
  ),
  AdvisoryCategory(
    id: 'one_way',
    title: 'One-Way',
    iconPath: 'assets/icons/one_way.webp',
    markerIconPath: 'assets/icons/one_way.webp',
    color: Color(0xFF1976D2), // Blue
  ),
  AdvisoryCategory(
    id: 'construction',
    title: 'Road Work / Construction',
    iconPath: 'assets/icons/road_construction.webp',
    markerIconPath: 'assets/icons/road_construction.webp',
    color: Color(0xFFF57C00), // Deep Orange
    requiresContractor: true,
  ),
  AdvisoryCategory(
    id: 'partial_lane',
    title: 'Partial Lane Closure',
    iconPath: 'assets/icons/partial_lane.webp',
    markerIconPath: 'assets/icons/partial_lane.webp',
    color: Color(0xFFFDD835), // Yellow
  ),
  AdvisoryCategory(
    id: 'event',
    title: 'Event-Related Advisory',
    iconPath: 'assets/icons/event.webp',
    markerIconPath: 'assets/icons/event.webp',
    color: Color(0xFF7B1FA2), // Purple
  ),
];

class Advisory {
  final String advisoryId;
  final String advisoryType;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String barangay;
  final AdvisoryScheduleType scheduleType;
  final List<int>? weekdays;
  final TimeOfDay? recurringStartTime;
  final TimeOfDay? recurringEndTime;
  final List<List<LatLng>>? affectedRoads;
  final List<List<LatLng>>? alternateRoutes;
  final LatLng? center;
  final String? contractor;
  final String? contractorContact;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;
  final AdvisoryStatus status;
  final String? imageUrl;
  final String? placeName;
  final int version; // For optimistic locking

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
    this.weekdays,
    this.recurringStartTime,
    this.recurringEndTime,
    this.affectedRoads,
    this.alternateRoutes,
    this.center,
    this.contractor,
    this.contractorContact,
    this.updatedBy,
    this.imageUrl,
    this.placeName,
    this.version = 1,
  });

  Advisory copyWith({
    String? advisoryId,
    String? advisoryType,
    String? reason,
    DateTime? startDate,
    DateTime? endDate,
    String? barangay,
    AdvisoryScheduleType? scheduleType,
    List<int>? weekdays,
    TimeOfDay? recurringStartTime,
    TimeOfDay? recurringEndTime,
    List<List<LatLng>>? affectedRoads,
    List<List<LatLng>>? alternateRoutes,
    LatLng? center,
    String? contractor,
    String? contractorContact,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    AdvisoryStatus? status,
    String? imageUrl,
    String? placeName,
    int? version,
  }) {
    return Advisory(
      advisoryId: advisoryId ?? this.advisoryId,
      advisoryType: advisoryType ?? this.advisoryType,
      reason: reason ?? this.reason,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      barangay: barangay ?? this.barangay,
      scheduleType: scheduleType ?? this.scheduleType,
      weekdays: weekdays ?? this.weekdays,
      recurringStartTime: recurringStartTime ?? this.recurringStartTime,
      recurringEndTime: recurringEndTime ?? this.recurringEndTime,
      affectedRoads: affectedRoads ?? this.affectedRoads,
      alternateRoutes: alternateRoutes ?? this.alternateRoutes,
      center: center ?? this.center,
      contractor: contractor ?? this.contractor,
      contractorContact: contractorContact ?? this.contractorContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      placeName: placeName ?? this.placeName,
      version: version ?? this.version,
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

  /// Firestore-safe JSON serialization
  Map<String, dynamic> toJson() => {
    'advisoryId': advisoryId,
    'advisoryType': advisoryType,
    'reason': reason,
    // store as Firestore Timestamps for correct querying and indexing
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'barangay': barangay,
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
    'center': center != null
        ? {'lat': center!.latitude, 'lng': center!.longitude}
        : null,
    'contractor': contractor,
    'contractorContact': contractorContact,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
    'status': status.name,
    'imageUrl': imageUrl,
    'placeName': placeName,
    'version': version,
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
      center = LatLng(json['center']['lat'], json['center']['lng']);
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

    return Advisory(
      advisoryId: advisoryId ?? json['advisoryId'] ?? '',
      advisoryType: json['advisoryType'] ?? '',
      reason: json['reason'] ?? '',
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      barangay: json['barangay'] ?? '',
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
      center: center ?? computeCenter(parsePolylines(json['affectedRoads'])),
      contractor: json['contractor'],
      contractorContact: json['contractorContact'],
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      createdBy: json['createdBy'] ?? '',
      updatedBy: json['updatedBy'],
      status: AdvisoryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AdvisoryStatus.active,
      ),
      imageUrl: json['imageUrl'],
      placeName: json['placeName'],
      version: json['version'] ?? 1,
    );
  }
}

class AdvisoryCategory {
  final String id;
  final String title;
  final String iconPath;
  final String markerIconPath;
  final Color color;
  final bool requiresContractor;

  const AdvisoryCategory({
    required this.id,
    required this.title,
    required this.iconPath,
    required this.markerIconPath,
    required this.color,
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
}
