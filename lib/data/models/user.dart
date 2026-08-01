import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vcroad/data/models/barangay.dart';

enum UserRole { user, admin, sysadmin }

class UserDetails {
  final String userId;

  // Personal Info
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? suffix;
  final String email;
  final String phoneNumber;

  // Address Info
  final String street;
  final String houseNumber;
  final Barangay barangay;

  // Identity Verification
  final String? validIdPath;
  final String? selfiePath;
  final bool isVerified;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  // Role & Access
  final UserRole role;
  final bool isBanned;
  final String? banReason;
  final String? banBy;
  final DateTime? bannedAt;
  final DateTime? unbanRequestAt;
  final String? unbannedBy;
  final DateTime? unbannedAt;
  final String? banType; // "temporary" or "permanent"
  final int? banDuration; // in days
  final DateTime? banExpiresAt;

  // Activity & Audit
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final DateTime? scheduledForDeletionAt;

  // Stats
  final int confirmReactionsCount;
  final int verifiedReportsCount;
  final int flaggedReportsCount;
  // Last login timestamp
  final DateTime? lastLoginAt;

  // Terms consent
  final DateTime? agreedToTermsAt;

  const UserDetails({
    required this.userId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.suffix,
    required this.email,
    required this.phoneNumber,
    required this.street,
    required this.houseNumber,
    required this.barangay,
    this.validIdPath,
    this.selfiePath,
    required this.isVerified,
    this.verifiedBy,
    this.verifiedAt,
    required this.role,
    required this.isBanned,
    this.banReason,
    this.banBy,
    this.bannedAt,
    this.unbanRequestAt,
    this.unbannedBy,
    this.unbannedAt,
    this.banType,
    this.banDuration,
    this.banExpiresAt,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.scheduledForDeletionAt,
    this.confirmReactionsCount = 0,
    this.verifiedReportsCount = 0,
    this.flaggedReportsCount = 0,
    this.lastLoginAt,
    this.agreedToTermsAt,
  });

  /// --- Helpers ---
  String get fullName {
    final baseName = [
      firstName,
      middleName,
      lastName,
    ].where((e) => e?.isNotEmpty ?? false).join(' ');

    return suffix?.isNotEmpty == true ? '$baseName, $suffix' : baseName;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static dynamic _toTimestamp(DateTime? value) {
    return value != null ? Timestamp.fromDate(value) : null;
  }

  /// Check if user ban has expired
  bool get isBanExpired {
    if (!isBanned || banType != 'temporary' || banExpiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(banExpiresAt!);
  }

  /// Get remaining ban time
  String get remainingBanTime {
    if (!isBanned || banExpiresAt == null) return '';

    final now = DateTime.now();
    if (now.isAfter(banExpiresAt!)) return 'Expired';

    final difference = banExpiresAt!.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} remaining';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} remaining';
    }
  }

  factory UserDetails.fromJson(Map<String, dynamic> json) {
    return UserDetails(
      userId: json['userId'] as String,
      firstName: json['firstName'] as String,
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String,
      suffix: json['suffix'] as String?,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      street: json['street'] as String? ?? '', // Handle missing/null
      houseNumber: json['houseNumber'] as String? ?? '', // Handle missing/null
      barangay: Barangay.fromJson(json['barangay'] as Map<String, dynamic>),
      validIdPath: json['validIdPath'] as String?,
      selfiePath: json['selfiePath'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      verifiedBy: json['verifiedBy'] as String?,
      verifiedAt: _toDateTime(json['verifiedAt']),
      role: UserRole.values.byName(json['role'] as String),
      isBanned: json['isBanned'] as bool? ?? false,
      banReason: json['banReason'] as String?,
      banBy: json['banBy'] as String?,
      bannedAt: _toDateTime(json['bannedAt']),
      unbanRequestAt: _toDateTime(json['unbanRequestAt']),
      unbannedBy: json['unbannedBy'] as String?,
      unbannedAt: _toDateTime(json['unbannedAt']),
      banType: json['banType'] as String?,
      banDuration: json['banDuration'] as int?,
      banExpiresAt: _toDateTime(json['banExpiresAt']),
      createdAt: _toDateTime(json['createdAt']) ?? DateTime.now(), // Fallback
      updatedAt: _toDateTime(json['updatedAt']),
      deletedAt: _toDateTime(json['deletedAt']),
      scheduledForDeletionAt: _toDateTime(json['scheduledForDeletionAt']),
      confirmReactionsCount: json['confirmReactionsCount'] as int? ?? 0,
      verifiedReportsCount: json['verifiedReportsCount'] as int? ?? 0,
      flaggedReportsCount: json['flaggedReportsCount'] as int? ?? 0,
      lastLoginAt: _toDateTime(json['lastLoginAt']),
      agreedToTermsAt: _toDateTime(json['agreedToTermsAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'suffix': suffix,
      'email': email,
      'phoneNumber': phoneNumber,
      'street': street,
      'houseNumber': houseNumber,
      'barangay': barangay.toJson(includePolygons: false),
      'validIdPath': validIdPath,
      'selfiePath': selfiePath,
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'verifiedAt': _toTimestamp(verifiedAt),
      'role': role.name,
      'isBanned': isBanned,
      'banReason': banReason,
      'banBy': banBy,
      'bannedAt': _toTimestamp(bannedAt),
      'unbanRequestAt': _toTimestamp(unbanRequestAt),
      'unbannedBy': unbannedBy,
      'unbannedAt': _toTimestamp(unbannedAt),
      'banType': banType,
      'banDuration': banDuration,
      'banExpiresAt': _toTimestamp(banExpiresAt),
      'createdAt': _toTimestamp(createdAt),
      'updatedAt': _toTimestamp(updatedAt),
      'deletedAt': _toTimestamp(deletedAt),
      'scheduledForDeletionAt': _toTimestamp(scheduledForDeletionAt),
      'confirmReactionsCount': confirmReactionsCount,
      'verifiedReportsCount': verifiedReportsCount,
      'flaggedReportsCount': flaggedReportsCount,
      'lastLoginAt': _toTimestamp(lastLoginAt),
      'agreedToTermsAt': _toTimestamp(agreedToTermsAt),
    };
  }

  UserDetails copyWith({
    String? userId,
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    String? email,
    String? phoneNumber,
    String? street,
    String? houseNumber,
    Barangay? barangay,
    String? validIdPath,
    String? selfiePath,
    bool? isVerified,
    String? verifiedBy,
    DateTime? verifiedAt,
    UserRole? role,
    // --- ban related (added) ---
    bool? isBanned,
    String? banReason,
    String? banBy,
    DateTime? bannedAt,
    DateTime? unbanRequestAt,
    String? unbannedBy,
    DateTime? unbannedAt,
    String? banType,
    int? banDuration,
    DateTime? banExpiresAt,
    // --- existing rest ---
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? scheduledForDeletionAt,
    int? confirmReactionsCount,
    int? verifiedReportsCount,
    int? flaggedReportsCount,
    DateTime? lastLoginAt,
    DateTime? agreedToTermsAt,
  }) {
    return UserDetails(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      barangay: barangay ?? this.barangay,
      validIdPath: validIdPath ?? this.validIdPath,
      selfiePath: selfiePath ?? this.selfiePath,
      isVerified: isVerified ?? this.isVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      role: role ?? this.role,
      // ban fields
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      banBy: banBy ?? this.banBy,
      bannedAt: bannedAt ?? this.bannedAt,
      unbanRequestAt: unbanRequestAt ?? this.unbanRequestAt,
      unbannedBy: unbannedBy ?? this.unbannedBy,
      unbannedAt: unbannedAt ?? this.unbannedAt,
      banType: banType ?? this.banType,
      banDuration: banDuration ?? this.banDuration,
      banExpiresAt: banExpiresAt ?? this.banExpiresAt,
      // rest
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledForDeletionAt:
          scheduledForDeletionAt ?? this.scheduledForDeletionAt,
      confirmReactionsCount:
          confirmReactionsCount ?? this.confirmReactionsCount,
      verifiedReportsCount: verifiedReportsCount ?? this.verifiedReportsCount,
      flaggedReportsCount: flaggedReportsCount ?? this.flaggedReportsCount,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      agreedToTermsAt: agreedToTermsAt ?? this.agreedToTermsAt,
    );
  }
}

extension UserDetailsJsonSafe on UserDetails {
  Map<String, dynamic> toJsonSafe() {
    return {
      'userId': userId,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'suffix': suffix,
      'email': email,
      'phoneNumber': phoneNumber,
      'street': street,
      'houseNumber': houseNumber,
      'barangay': barangay.toJson(includePolygons: false),
      'validIdPath': validIdPath,
      'selfiePath': selfiePath,
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'role': role.name,
      'isBanned': isBanned,
      'banReason': banReason,
      'banBy': banBy,
      'bannedAt': bannedAt?.toIso8601String(),
      'unbanRequestAt': unbanRequestAt?.toIso8601String(),
      'unbannedBy': unbannedBy,
      'unbannedAt': unbannedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'scheduledForDeletionAt': scheduledForDeletionAt?.toIso8601String(),
      'confirmReactionsCount': confirmReactionsCount,
      'verifiedReportsCount': verifiedReportsCount,
      'flaggedReportsCount': flaggedReportsCount,
      'agreedToTermsAt': agreedToTermsAt?.toIso8601String(),
    };
  }
}

extension UserDetailsComputed on UserDetails {
  bool get isInactive => scheduledForDeletionAt != null && deletedAt == null;
  String get primaryStatus {
    if (isBanned) return 'banned';
    if (isInactive) return 'inactive';
    if (isVerified) return 'verified';
    return 'unverified';
  }
}
