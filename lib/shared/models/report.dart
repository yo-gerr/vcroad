import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ReportCategory {
  roadAccident,
  roadFlooding,
  roadConstruction,
  brokenSignage,
  outdatedPosters,
  roadObstruction,
}

extension ReportCategoryExtension on ReportCategory {
  String get label {
    switch (this) {
      case ReportCategory.roadAccident:
        return 'Road Accident';
      case ReportCategory.roadFlooding:
        return 'Road Flooding';
      case ReportCategory.roadConstruction:
        return 'Road Construction';
      case ReportCategory.brokenSignage:
        return 'Broken Signage';
      case ReportCategory.outdatedPosters:
        return 'Outdated Posters';
      case ReportCategory.roadObstruction:
        return 'Road Obstruction';
    }
  }

  String get asset {
    switch (this) {
      case ReportCategory.roadAccident:
        return 'assets/icons/road_accident.webp';
      case ReportCategory.roadFlooding:
        return 'assets/icons/flooding.webp';
      case ReportCategory.roadConstruction:
        return 'assets/icons/construction.webp';
      case ReportCategory.brokenSignage:
        return 'assets/icons/broken_signage.webp';
      case ReportCategory.outdatedPosters:
        return 'assets/icons/outdated_poster.webp';
      case ReportCategory.roadObstruction:
        return 'assets/icons/road_obstruction.webp';
    }
  }

  String get description {
    switch (this) {
      case ReportCategory.roadAccident:
        return 'Traffic accidents, collisions, or vehicle breakdowns';
      case ReportCategory.roadFlooding:
        return 'Flooded roads or waterlogged areas';
      case ReportCategory.roadConstruction:
        return 'Ongoing road repairs or construction work';
      case ReportCategory.brokenSignage:
        return 'Damaged or missing road signs';
      case ReportCategory.outdatedPosters:
        return 'Old campaign posters or illegal signage';
      case ReportCategory.roadObstruction:
        return 'Blocked roads, fallen trees, or obstacles';
    }
  }

  /// Color associated with each category (centralized for reuse in UI)
  Color get color {
    switch (this) {
      case ReportCategory.roadAccident:
        return Colors.redAccent;
      case ReportCategory.roadFlooding:
        return Colors.blue;
      case ReportCategory.roadConstruction:
        return Colors.orange;
      case ReportCategory.brokenSignage:
        return Colors.indigo;
      case ReportCategory.outdatedPosters:
        return Colors.teal;
      case ReportCategory.roadObstruction:
        return Colors.deepPurple;
    }
  }
}

enum MediaType { photo, video }

enum ReportStatus {
  pending, // Initial state
  verified, // Admin verified
  resolved, // Admin resolved
  flagged, // Admin flagged as inappropriate/spam
}

extension ReportStatusExtension on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.verified:
        return 'Verified';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.flagged:
        return 'Flagged';
    }
  }

  // remove the manual switch-based colorHex and compute from `color` instead
  String get colorHex {
    // Convert Color (0xAARRGGBB) to '#RRGGBB'
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${hex.substring(2)}';
  }

  /// Material Color for UI use
  Color get color {
    switch (this) {
      case ReportStatus.pending:
        return Colors.grey;
      case ReportStatus.verified:
        return Colors.green;
      case ReportStatus.resolved:
        return Colors.blue;
      case ReportStatus.flagged:
        return Colors.red;
    }
  }
}

class ReportData {
  final String reportId;
  final String userId;

  // User information (snapshot at time of report)
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? suffix;
  final String email;
  final String phoneNumber;

  // Report details
  final ReportCategory category;
  final MediaType mediaType;
  final String mediaPath; // Storage path
  final String? mediaUrl; // Download URL (cached for faster access)

  // Location information
  final double latitude;
  final double longitude;
  final String address;
  final String barangay;

  // Status tracking
  final bool isVerified;
  final bool isResolved;
  final bool isFlagged;

  // Timestamps
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final DateTime? resolvedAt;
  final DateTime? flaggedAt;
  final DateTime? flagDismissedAt;
  final DateTime? updatedAt; // Last status change

  // Action tracking
  final String? verifiedBy; // Admin/SysAdmin userId
  final String? resolvedBy; // Admin/SysAdmin userId
  final String? flaggedBy; // Admin/SysAdmin userId

  // Additional information
  final String? note; // Admin notes

  // Community interaction tracking
  final int confirmCount; // Users who confirmed this report
  final int refuteCount; // Users who refuted this report
  final List<String> confirmedBy; // User IDs who confirmed
  final List<String> refutedBy; // User IDs who refuted

  // Metadata
  final int viewCount; // Number of times report was viewed
  final bool isActive; // Soft delete flag

  ReportData({
    required this.reportId,
    required this.userId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.suffix,
    required this.email,
    required this.phoneNumber,
    required this.category,
    required this.mediaType,
    required this.mediaPath,
    this.mediaUrl,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.barangay,
    this.isVerified = false,
    this.isResolved = false,
    this.isFlagged = false,
    required this.createdAt,
    this.verifiedAt,
    this.resolvedAt,
    this.flaggedAt,
    this.flagDismissedAt,
    this.updatedAt,
    this.verifiedBy,
    this.resolvedBy,
    this.flaggedBy,
    this.note,
    this.confirmCount = 0,
    this.refuteCount = 0,
    this.confirmedBy = const [],
    this.refutedBy = const [],
    this.viewCount = 0,
    this.isActive = true,
  });

  /// Get computed status based on flags
  ReportStatus get status {
    if (isFlagged) return ReportStatus.flagged;
    if (isResolved) return ReportStatus.resolved;
    if (isVerified) return ReportStatus.verified;
    return ReportStatus.pending;
  }

  /// Get full name with proper formatting
  String get fullName {
    final parts = <String>[
      firstName,
      if (middleName != null && middleName!.isNotEmpty) middleName!,
      lastName,
      if (suffix != null && suffix!.isNotEmpty) suffix!,
    ];
    return parts.join(' ');
  }

  /// Get current status label
  String get statusLabel => status.label;

  /// Get status color
  // prefer returning a Color for UI; call `.colorHex` if a hex string is specifically required
  Color get statusColor => status.color;

  /// Calculate credibility score based on community feedback
  double get credibilityScore {
    final total = confirmCount + refuteCount;
    if (total == 0) return 0.5; // Neutral score when no feedback
    return confirmCount / total;
  }

  /// Get credibility rating (1-5 stars)
  int get credibilityRating {
    final score = credibilityScore;
    if (score >= 0.9) return 5;
    if (score >= 0.75) return 4;
    if (score >= 0.6) return 3;
    if (score >= 0.4) return 2;
    return 1;
  }

  /// Check if a user has interacted with this report
  bool hasUserConfirmed(String userId) => confirmedBy.contains(userId);
  bool hasUserRefuted(String userId) => refutedBy.contains(userId);
  bool hasUserInteracted(String userId) =>
      hasUserConfirmed(userId) || hasUserRefuted(userId);

  /// Check if user can interact with this report
  bool canUserInteract(String userId) {
    // User cannot interact with their own reports
    if (userId == this.userId) return false;
    // User cannot interact with flagged reports
    if (isFlagged) return false;
    // User cannot interact with resolved reports
    if (isResolved) return false;
    return true;
  }

  /// Get LatLng for map display
  LatLng get location => LatLng(latitude, longitude);

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'suffix': suffix,
      'email': email,
      'phoneNumber': phoneNumber,
      'category': category.name,
      'mediaType': mediaType.name,
      'mediaPath': mediaPath,
      'mediaUrl': mediaUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'barangay': barangay,
      'isVerified': isVerified,
      'isResolved': isResolved,
      'isFlagged': isFlagged,
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'flaggedAt': flaggedAt != null ? Timestamp.fromDate(flaggedAt!) : null,
      'flagDismissedAt': flagDismissedAt != null
          ? Timestamp.fromDate(flagDismissedAt!)
          : null,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : Timestamp.fromDate(createdAt),
      'verifiedBy': verifiedBy,
      'resolvedBy': resolvedBy,
      'flaggedBy': flaggedBy,
      'note': note,
      'confirmCount': confirmCount,
      'refuteCount': refuteCount,
      'confirmedBy': confirmedBy,
      'refutedBy': refutedBy,
      'viewCount': viewCount,
      'isActive': isActive,
    };
  }

  factory ReportData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportData(
      reportId: doc.id,
      userId: data['userId'] ?? '',
      firstName: data['firstName'] ?? '',
      middleName: data['middleName'],
      lastName: data['lastName'] ?? '',
      suffix: data['suffix'],
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      category: ReportCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ReportCategory.roadObstruction,
      ),
      mediaType: MediaType.values.firstWhere(
        (e) => e.name == data['mediaType'],
        orElse: () => MediaType.photo,
      ),
      mediaPath: data['mediaPath'] ?? '',
      mediaUrl: data['mediaUrl'],
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      address: data['address'] ?? '',
      barangay: data['barangay'] ?? '',
      isVerified: data['isVerified'] ?? false,
      isResolved: data['isResolved'] ?? false,
      isFlagged: data['isFlagged'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      flaggedAt: (data['flaggedAt'] as Timestamp?)?.toDate(),
      flagDismissedAt: (data['flagDismissedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      verifiedBy: data['verifiedBy'],
      resolvedBy: data['resolvedBy'],
      flaggedBy: data['flaggedBy'],
      note: data['note'],
      confirmCount: data['confirmCount'] ?? 0,
      refuteCount: data['refuteCount'] ?? 0,
      confirmedBy: List<String>.from(data['confirmedBy'] ?? []),
      refutedBy: List<String>.from(data['refutedBy'] ?? []),
      viewCount: data['viewCount'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  /// Create a copy with updated fields
  ReportData copyWith({
    String? mediaUrl,
    bool? isVerified,
    bool? isResolved,
    bool? isFlagged,
    DateTime? verifiedAt,
    DateTime? resolvedAt,
    DateTime? flaggedAt,
    DateTime? flagDismissedAt,
    DateTime? updatedAt,
    String? verifiedBy,
    String? resolvedBy,
    String? flaggedBy,
    String? note,
    int? confirmCount,
    int? refuteCount,
    List<String>? confirmedBy,
    List<String>? refutedBy,
    int? viewCount,
    bool? isActive,
  }) {
    return ReportData(
      reportId: reportId,
      userId: userId,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      suffix: suffix,
      email: email,
      phoneNumber: phoneNumber,
      category: category,
      mediaType: mediaType,
      mediaPath: mediaPath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      barangay: barangay,
      isVerified: isVerified ?? this.isVerified,
      isResolved: isResolved ?? this.isResolved,
      isFlagged: isFlagged ?? this.isFlagged,
      createdAt: createdAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      flaggedAt: flaggedAt ?? this.flaggedAt,
      flagDismissedAt: flagDismissedAt ?? this.flagDismissedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      flaggedBy: flaggedBy ?? this.flaggedBy,
      note: note ?? this.note,
      confirmCount: confirmCount ?? this.confirmCount,
      refuteCount: refuteCount ?? this.refuteCount,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      refutedBy: refutedBy ?? this.refutedBy,
      viewCount: viewCount ?? this.viewCount,
      isActive: isActive ?? this.isActive,
    );
  }
}
