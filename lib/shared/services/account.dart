import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:flutter/foundation.dart'; // added for debugPrint
import 'package:firebase_auth/firebase_auth.dart'; // added
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/models/stats.dart';

class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Replace these with secure config (do NOT hardcode in production)
  static const String _algoliaAppId = 'SLV39AYAB8';
  static const String _algoliaApiKey = '349e79b533a91ad8b5c1790485696240';
  static const String _algoliaIndex = 'users_index';

  Uri _algoliaQueryUri() => Uri.https(
    '$_algoliaAppId-dsn.algolia.net',
    '/1/indexes/$_algoliaIndex/query',
  );

  /// Search users using Algolia REST API. Falls back to Firestore on error.
  Future<List<UserDetails>> searchUsers({
    required String query,
    List<UserRole>? roleFilters,
    List<String>? statusFilters,
    String? barangayFilter,
    int hitsPerPage = 20,
    int page = 0,
    UserDetails? currentUser, // <-- added
  }) async {
    try {
      final facetFilters = <dynamic>[];

      // Force admin scope (always override incoming filters)
      if (currentUser?.role == UserRole.admin) {
        facetFilters.add('role:user');
        facetFilters.add('barangay.name:${currentUser!.barangay.name}');
      } else {
        if (barangayFilter != null && barangayFilter.isNotEmpty) {
          facetFilters.add('barangay.name:$barangayFilter');
        }
        if (roleFilters != null && roleFilters.isNotEmpty) {
          facetFilters.addAll(roleFilters.map((r) => 'role:${r.name}'));
        }
      }

      if (statusFilters != null && statusFilters.isNotEmpty) {
        for (final s in statusFilters) {
          switch (s) {
            case 'verified':
              facetFilters.add('isVerified:true');
              break;
            case 'unverified':
              facetFilters.add('isVerified:false');
              break;
            case 'banned':
              facetFilters.add('isBanned:true');
              break;
            case 'flagged':
              break;
            case 'inactive':
              break;
            default:
              break;
          }
        }
      }

      final List<String> numericFilters = [];
      if (statusFilters != null && statusFilters.contains('flagged')) {
        numericFilters.add('flaggedReportsCount>0');
      }

      final body = <String, dynamic>{
        'query': query,
        'hitsPerPage': hitsPerPage,
        'page': page,
        if (facetFilters.isNotEmpty) 'facetFilters': facetFilters,
        if (numericFilters.isNotEmpty) 'numericFilters': numericFilters,
      };

      final response = await http.post(
        _algoliaQueryUri(),
        headers: {
          'X-Algolia-Application-Id': _algoliaAppId,
          'X-Algolia-API-Key': _algoliaApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Algolia search failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final hits = (data['hits'] as List<dynamic>? ?? <dynamic>[]);

      final List<UserDetails> users = [];
      for (final hit in hits) {
        if (hit is Map<String, dynamic>) {
          try {
            users.add(UserDetails.fromJson(hit));
          } catch (e) {
            debugPrint('UserDetails.fromJson failed: $e\nData: $hit');
            continue;
          }
        }
      }

      return users;
    } catch (e, st) {
      debugPrint('Algolia search error: $e');
      debugPrint('Stack: $st');
      return _fallbackSearch(
        query,
        roleFilters,
        statusFilters,
        currentUser: currentUser,
        barangayFilter: barangayFilter,
      );
    }
  }

  /// Fallback search using Firestore
  Future<List<UserDetails>> _fallbackSearch(
    String query,
    List<UserRole>? roleFilters,
    List<String>? statusFilters, {
    UserDetails? currentUser,
    String? barangayFilter,
  }) async {
    Query<Map<String, dynamic>> firestoreQuery = _firestore.collection('users');

    final isAdmin = currentUser?.role == UserRole.admin;
    if (isAdmin) {
      firestoreQuery = firestoreQuery
          .where('role', isEqualTo: 'user')
          .where('barangay.name', isEqualTo: currentUser!.barangay.name);
    } else {
      if (roleFilters != null && roleFilters.isNotEmpty) {
        firestoreQuery = firestoreQuery.where(
          'role',
          whereIn: roleFilters.map((r) => r.name).toList(),
        );
      }
      if (barangayFilter != null && barangayFilter.isNotEmpty) {
        firestoreQuery = firestoreQuery.where(
          'barangay.name',
          isEqualTo: barangayFilter,
        );
      }
    }

    final snapshot = await firestoreQuery.limit(50).get();
    final searchLower = query.toLowerCase();
    final results = snapshot.docs
        .map((doc) => UserDetails.fromJson(doc.data()))
        .where(
          (user) =>
              user.fullName.toLowerCase().contains(searchLower) ||
              user.email.toLowerCase().contains(searchLower) ||
              user.phoneNumber.toLowerCase().contains(searchLower) ||
              user.houseNumber.toLowerCase().contains(searchLower) ||
              user.street.toLowerCase().contains(searchLower) ||
              user.barangay.name.toLowerCase().contains(searchLower),
        )
        .toList();

    if (statusFilters != null && statusFilters.isNotEmpty) {
      var filtered = results;
      if (statusFilters.contains('flagged')) {
        filtered = filtered.where((u) => (u.flaggedReportsCount) > 0).toList();
      }
      if (statusFilters.contains('verified')) {
        filtered = filtered.where((u) => u.isVerified).toList();
      }
      if (statusFilters.contains('unverified')) {
        filtered = filtered.where((u) => !u.isVerified).toList();
      }
      if (statusFilters.contains('banned')) {
        filtered = filtered.where((u) => u.isBanned).toList();
      }
      if (statusFilters.contains('inactive')) {
        filtered = filtered
            .where((u) => u.scheduledForDeletionAt != null)
            .toList();
      }
      return filtered;
    }

    return results;
  }

  /// Get paginated users (for initial load without search)
  Future<List<UserDetails>> getUsers({
    int limit = 20,
    DocumentSnapshot? startAfter,
    List<UserRole>? roleFilters,
    List<String>? statusFilters,
    String? barangayFilter,
    UserDetails? currentUser,
  }) async {
    // Avoid making Firestore requests when the client is signed out
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      debugPrint(
        'Skipping getUsers: no authenticated user (likely signing out).',
      );
      return <UserDetails>[];
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .orderBy('createdAt', descending: true);

    final isAdmin = currentUser?.role == UserRole.admin;
    if (isAdmin) {
      query = query
          .where('role', isEqualTo: 'user')
          .where('barangay.name', isEqualTo: currentUser!.barangay.name);
    } else {
      if (roleFilters != null && roleFilters.isNotEmpty) {
        query = query.where(
          'role',
          whereIn: roleFilters.map((r) => r.name).toList(),
        );
      }
      if (barangayFilter != null && barangayFilter.isNotEmpty) {
        query = query.where('barangay.name', isEqualTo: barangayFilter);
      }
    }

    // Try to apply filters server-side where supported by Firestore
    if (statusFilters != null && statusFilters.isNotEmpty) {
      // Banned
      if (statusFilters.contains('banned') &&
          !statusFilters.contains('verified') &&
          !statusFilters.contains('unverified')) {
        query = query.where('isBanned', isEqualTo: true);
      } else if (statusFilters.contains('verified') &&
          !statusFilters.contains('unverified')) {
        query = query.where('isVerified', isEqualTo: true);
      } else if (statusFilters.contains('unverified') &&
          !statusFilters.contains('verified')) {
        query = query.where('isVerified', isEqualTo: false);
      }

      // Flagged (numeric)
      if (statusFilters.contains('flagged')) {
        query = query.where('flaggedReportsCount', isGreaterThan: 0);
      }

      // Inactive: scheduledForDeletionAt exists (timestamp > epoch)
      if (statusFilters.contains('inactive')) {
        query = query.where(
          'scheduledForDeletionAt',
          isGreaterThan: Timestamp.fromDate(
            DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      }

      // Barangay or other facet filters can be added here if needed
    }

    if (startAfter != null) query = query.startAfterDocument(startAfter);

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.limit(limit).get();
    } on FirebaseException catch (e, st) {
      // Log full Firestore error (includes create-index link when applicable)
      debugPrint(
        'Firestore getUsers failed: code=${e.code}, message=${e.message}',
      );
      debugPrint(
        'Query details -> roleFilters: $roleFilters, statusFilters: $statusFilters, barangayFilter: $barangayFilter, startAfter: ${startAfter?.id}, limit: $limit',
      );
      debugPrint('Stack: $st');
      // rethrow so caller can handle UI state; remove rethrow if you prefer to return empty list
      rethrow;
    } catch (e, st) {
      debugPrint('Unexpected error in getUsers: $e');
      debugPrint('Stack: $st');
      rethrow;
    }
    List<UserDetails> users = snapshot.docs
        .map((doc) => UserDetails.fromJson(doc.data()))
        .toList();

    // Client-side safety filters for cases Firestore couldn't handle (or complex combos)
    if (statusFilters != null && statusFilters.isNotEmpty) {
      var filtered = users;

      if (statusFilters.contains('flagged')) {
        filtered = filtered.where((u) => (u.flaggedReportsCount) > 0).toList();
      }
      if (statusFilters.contains('verified')) {
        filtered = filtered.where((u) => u.isVerified).toList();
      }
      if (statusFilters.contains('unverified')) {
        filtered = filtered.where((u) => !u.isVerified).toList();
      }
      if (statusFilters.contains('banned')) {
        filtered = filtered.where((u) => u.isBanned).toList();
      }
      if (statusFilters.contains('inactive')) {
        filtered = filtered
            .where((u) => u.scheduledForDeletionAt != null)
            .toList();
      }

      users = filtered;
    }

    return users;
  }

  /// Update user verification status
  Future<void> updateVerificationStatus({
    required String userId,
    required bool isVerified,
    required String verifiedBy,
  }) async {
    await _firestore.doc('users/$userId').update({
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'verifiedAt': isVerified ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ban/Unban user
  Future<void> updateBanStatus({
    required String userId,
    required bool isBanned,
    String? banReason,
    required String actionBy,
    String? banType,
    int? banDuration,
  }) async {
    final data = <String, dynamic>{
      'isBanned': isBanned,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isBanned) {
      data['banReason'] = banReason;
      data['banBy'] = actionBy;
      data['bannedAt'] = FieldValue.serverTimestamp();
      data['banType'] = banType ?? 'permanent';

      if (banType == 'temporary' && banDuration != null) {
        data['banDuration'] = banDuration;
        data['banExpiresAt'] = Timestamp.fromDate(
          DateTime.now().add(Duration(days: banDuration)),
        );
      }
    } else {
      data['unbannedBy'] = actionBy;
      data['unbannedAt'] = FieldValue.serverTimestamp();
      data['banExpiresAt'] = null;
    }

    await _firestore.doc('users/$userId').update(data);
  }

  /// Schedule user for deletion (soft delete, scheduled for 30 days)
  Future<void> scheduleForDeletion(String userId) async {
    final scheduledDate = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(userId).set({
      'scheduledForDeletionAt': Timestamp.fromDate(scheduledDate),
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Cancel deletion schedule (remove scheduledForDeletionAt and deletedAt)
  Future<void> cancelDeletionSchedule(String userId) async {
    await _firestore.collection('users').doc(userId).set({
      'scheduledForDeletionAt': FieldValue.delete(),
      'deletedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user statistics
  Future<Map<String, int>> getUserStats({String? barangayName}) async {
    // Only count documents whose role is 'user' for accurate user stats
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'user');
    if (barangayName != null && barangayName.isNotEmpty) {
      query = query.where('barangay.name', isEqualTo: barangayName);
    }
    final snapshot = await query.get();
    int total = snapshot.size;
    int verified = 0;
    int unverified = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isVerified'] == true) {
        verified++;
      } else {
        unverified++;
      }
    }
    return {'total': total, 'verified': verified, 'unverified': unverified};
  }

  /// Get a single user by id
  Future<UserDetails?> getUserById(String userId) async {
    try {
      final doc = await _firestore.doc('users/$userId').get();
      if (!doc.exists) return null;
      return UserDetails.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('getUserById failed for $userId: $e');
      return null;
    }
  }

  /// Get per-barangay user statistics (verified / unverified).
  /// Performs a single Firestore read of all users with role == 'user' then
  /// aggregates client-side to avoid expensive multiple queries.
  Future<List<BarangayUserStat>> getUserStatsPerBarangay({
    String? barangayFilter,
    bool includeZeroEntries = true,
  }) async {
    final Map<String, _Counts> agg = {};

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'user');

    if (barangayFilter != null && barangayFilter.isNotEmpty) {
      query = query.where('barangay.name', isEqualTo: barangayFilter);
    }

    final snapshot = await query.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final b = (data['barangay'] is Map && data['barangay']['name'] != null)
          ? (data['barangay']['name'] as String)
          : (data['barangay'] as String?) ?? 'Unknown';

      final isVerified = data['isVerified'] == true;
      final c = agg.putIfAbsent(b, () => _Counts());
      if (isVerified) {
        c.verified++;
      } else {
        c.unverified++;
      }
    }

    // Optionally include zero-count barangays known from bundled BarangayService
    if (includeZeroEntries) {
      try {
        final bs = BarangayService();
        if (bs.isLoaded && bs.barangays.isNotEmpty) {
          for (final b in bs.barangays) {
            agg.putIfAbsent(b.name, () => _Counts());
          }
        }
      } catch (_) {
        // ignore errors from optional dependency
      }
    }

    // Convert to list and sort by total desc
    final List<BarangayUserStat> out = agg.entries.map((e) {
      return BarangayUserStat(
        barangay: e.key,
        total: e.value.total,
        verified: e.value.verified,
        unverified: e.value.unverified,
      );
    }).toList()..sort((a, b) => b.total.compareTo(a.total));

    return out;
  }
}

// small private helper used only in this file
class _Counts {
  int verified = 0;
  int unverified = 0;
  int get total => verified + unverified;
}
