import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:flutter/foundation.dart'; // added for debugPrint
import 'package:firebase_auth/firebase_auth.dart'; // added
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/data/models/stats.dart';

class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search users using Firestore. Applies the same scoping and filters as
  /// `getUsers`, then narrows results client-side by matching the query against
  /// common searchable fields.
  ///
  /// Because Firestore has no native substring search, results are produced by
  /// scanning store pages (bounded by [scanBatch] and [maxScanPages]) in
  /// `createdAt` order until enough matches are collected. This makes search
  /// reach users wherever they sit in the collection instead of only the first
  /// page. All reads are bounded to stay within Firestore free-tier quotas.
  Future<({List<UserDetails> users, DocumentSnapshot? cursor, bool hasMore})>
  searchUsers({
    required String query,
    List<UserRole>? roleFilters,
    List<String>? statusFilters,
    String? barangayFilter,
    int hitsPerPage = 20,
    int scanBatch = 50,
    int maxScanPages = 10,
    DocumentSnapshot? startAfter,
    UserDetails? currentUser,
  }) async {
    // Avoid making Firestore requests when the client is signed out.
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      return (users: const <UserDetails>[], cursor: null, hasMore: false);
    }

    final searchLower = query.toLowerCase();
    bool textMatch(UserDetails user) =>
        user.fullName.toLowerCase().contains(searchLower) ||
        user.email.toLowerCase().contains(searchLower) ||
        user.phoneNumber.toLowerCase().contains(searchLower) ||
        user.houseNumber.toLowerCase().contains(searchLower) ||
        user.street.toLowerCase().contains(searchLower) ||
        user.barangay.name.toLowerCase().contains(searchLower);

    final matched = <UserDetails>[];
    DocumentSnapshot? cursor = startAfter;
    var pagesScanned = 0;
    var exhausted = false;

    while (matched.length < hitsPerPage && pagesScanned < maxScanPages) {
      final page = await _searchPage(
        roleFilters: roleFilters,
        barangayFilter: barangayFilter,
        batch: scanBatch,
        startAfter: cursor,
        currentUser: currentUser,
      );

      pagesScanned++;

      if (page.rawUsers.isEmpty) {
        exhausted = true;
        break;
      }

      // Cursor always advances by the last raw doc fetched on this page.
      cursor = page.lastDoc;

      for (final user in page.rawUsers) {
        if (textMatch(user)) {
          matched.add(user);
        }
      }

      // A page shorter than the batch means there are no more documents.
      if (page.rawCount < scanBatch) {
        exhausted = true;
        if (matched.length >= hitsPerPage) break;
      }
    }

    // Continue client-side status filtering on the matched pool.
    final users = _applyStatusFilters(matched, statusFilters);

    final hasMore =
        !exhausted && (matched.length >= hitsPerPage || cursor != null);

    return (users: users, cursor: cursor, hasMore: hasMore);
  }

  Future<
    ({List<UserDetails> rawUsers, DocumentSnapshot? lastDoc, int rawCount})
  >
  _searchPage({
    List<UserRole>? roleFilters,
    String? barangayFilter,
    required int batch,
    DocumentSnapshot? startAfter,
    UserDetails? currentUser,
  }) async {
    Query<Map<String, dynamic>> firestoreQuery = _firestore
        .collection('users')
        .orderBy('createdAt', descending: true);

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

    if (startAfter != null) {
      firestoreQuery = firestoreQuery.startAfterDocument(startAfter);
    }

    final snapshot = await firestoreQuery.limit(batch).get();
    final rawUsers = snapshot.docs
        .map((doc) => UserDetails.fromJson(doc.data()))
        .toList();

    return (
      rawUsers: rawUsers,
      lastDoc: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      rawCount: snapshot.docs.length,
    );
  }

  List<UserDetails> _applyStatusFilters(
    List<UserDetails> results,
    List<String>? statusFilters,
  ) {
    if (statusFilters == null || statusFilters.isEmpty) return results;
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
      filtered = filtered.where((u) => u.hasActiveBan).toList();
    }
    if (statusFilters.contains('inactive')) {
      filtered = filtered
          .where((u) => u.scheduledForDeletionAt != null)
          .toList();
    }
    return filtered;
  }

  /// Get paginated users (for initial load without search).
  ///
  /// [cursor] resumes an earlier page (the previous page's `cursor`); [hasMore]
  /// indicates whether a further page may exist.
  Future<({List<UserDetails> users, DocumentSnapshot? cursor, bool hasMore})>
  getUsers({
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
      return (users: const <UserDetails>[], cursor: null, hasMore: false);
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

    // NOTE: Status filters (banned / verified / unverified / flagged /
    // inactive) are intentionally NOT pushed to the server. Doing so would
    // require one composite index per (scope × status-field) combination, which
    // is fragile and index-heavy. Instead the base query stays lean (scope +
    // createdAt order) and statuses are narrowed client-side by
    // `_applyStatusFilters` below, so only the declared role/barangay +
    // createdAt composite indexes are ever needed.

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
    users = _applyStatusFilters(users, statusFilters);

    final cursor = snapshot.docs.isEmpty
        ? null
        : snapshot.docs.last as DocumentSnapshot;

    return (
      users: users,
      cursor: cursor,
      hasMore: snapshot.docs.length == limit,
    );
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
      // Clear stale ban fields so a re-ban never inherits an old reason,
      // actor, timestamp, type, or duration.
      data['banReason'] = FieldValue.delete();
      data['banBy'] = FieldValue.delete();
      data['bannedAt'] = FieldValue.delete();
      data['banType'] = FieldValue.delete();
      data['banDuration'] = FieldValue.delete();
      data['banExpiresAt'] = FieldValue.delete();
    }

    await _firestore.doc('users/$userId').update(data);
  }

  /// Schedule user for deletion (soft delete, scheduled for 30 days).
  ///
  /// Only `scheduledForDeletionAt` is set here; `deletedAt` is written only at
  /// actual deletion so the `isInactive` ("Scheduled deletion") state stays
  /// observable until the account is really removed.
  Future<void> scheduleForDeletion(String userId) async {
    final scheduledDate = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(userId).set({
      'scheduledForDeletionAt': Timestamp.fromDate(scheduledDate),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Creates a barangay admin account on the client.
  ///
  /// Admin accounts are verified by default and do not require ID capture or
  /// email verification. The Firebase Auth user is created first, then a fully
  /// populated `users/{uid}` document is written with role `admin`. Creating
  /// admin accounts client-side therefore requires the client project to be
  /// permitted to create users directly (no Cloud Functions dependency).
  ///
  /// Throws a `FirebaseAuthException` with code `email-already-in-use` when the
  /// email is taken; callers should present that to the user.
  Future<void> createAdminAccount({
    required String email,
    required String password,
    required Map<String, dynamic> userDetails,
    required Map<String, dynamic> barangay,
    required String createdBy,
  }) async {
    final auth = FirebaseAuth.instance;
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Account created but no uid returned. Please try again.');
    }

    try {
      await _firestore.collection('users').doc(uid).set({
        ...userDetails,
        'uid': uid,
        'userId': uid,
        'email': email.trim().toLowerCase(),
        'role': UserRole.admin.name,
        'barangay': barangay,
        'isVerified': true,
        'verifiedBy': createdBy,
        'verifiedAt': FieldValue.serverTimestamp(),
        'isBanned': false,
        'scheduledForDeletionAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Roll back the Auth account so no orphaned credential is left behind
      // when the user document could not be created.
      try {
        await credential.user?.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Get user statistics.
  ///
  /// Delegates to the shared, bounded, cached aggregation so the home header
  /// and the per-barangay dashboard never perform two full-table reads.
  Future<Map<String, int>> getUserStats({String? barangayName}) async {
    final counts = await _fetchUserCounts(barangayFilter: barangayName);
    int total = 0;
    int verified = 0;
    int unverified = 0;
    for (final c in counts.values) {
      total += c.total;
      verified += c.verified;
      unverified += c.unverified;
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
  ///
  /// Aggregates client-side from the shared bounded, cached read so repeated
  /// visits within the TTL window avoid scanning the whole users collection.
  Future<List<BarangayUserStat>> getUserStatsPerBarangay({
    String? barangayFilter,
    bool includeZeroEntries = true,
    bool forceRefresh = false,
  }) async {
    // Copy so zero-entry barangays don't leak into the shared cache.
    final agg = Map<String, _Counts>.from(
      await _fetchUserCounts(
        barangayFilter: barangayFilter,
        forceRefresh: forceRefresh,
      ),
    );

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

  // ---------------------------------------------------------------------------
  // Shared bounded user-count aggregation
  // ---------------------------------------------------------------------------

  static const _statsPageSize = 400;
  static const _statsMaxDocs = 5000;
  static const _statsCacheTtl = Duration(minutes: 5);
  static const _statsUnknownBarangay = 'Unknown';

  // Raw aggregation (barangay -> counts) keyed by filter, with fetch time.
  final Map<String, _CountsCacheEntry> _statsCache = {};

  /// Aggregates all `role == 'user'` documents (optionally narrowed to a single
  /// barangay) into per-barangay counts.
  ///
  /// The collection is read in bounded cursor pages (ordered by `createdAt`,
  /// with `startAfterDocument` cursors) so no single request pulls the entire
  /// table into memory and reads stay within Firestore free-tier limits.
  /// Document cursors require `__name__` tiebreaker composite indexes, declared
  /// in `firestore.indexes.json` (e.g. `role + createdAt + __name__`). Results
  /// are cached for [_statsCacheTtl]; pass [forceRefresh] to bypass the cache.
  Future<Map<String, _Counts>> _fetchUserCounts({
    String? barangayFilter,
    bool forceRefresh = false,
  }) async {
    final cacheKey = (barangayFilter == null || barangayFilter.isEmpty)
        ? 'all'
        : 'brgy:$barangayFilter';

    final now = DateTime.now();
    if (!forceRefresh) {
      final cached = _statsCache[cacheKey];
      if (cached != null && now.difference(cached.fetchedAt) < _statsCacheTtl) {
        return cached.counts;
      }
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'user')
        .orderBy('createdAt');

    if (barangayFilter != null && barangayFilter.isNotEmpty) {
      query = query.where('barangay.name', isEqualTo: barangayFilter);
    }

    final agg = <String, _Counts>{};
    DocumentSnapshot? cursor;
    var scanned = 0;

    while (scanned < _statsMaxDocs) {
      var page = query.limit(_statsPageSize);
      if (cursor != null) {
        page = page.startAfterDocument(cursor);
      }
      final snapshot = await page.get();
      final docs = snapshot.docs;
      scanned += docs.length;
      for (final doc in docs) {
        final data = doc.data();
        final b = (data['barangay'] is Map && data['barangay']['name'] != null)
            ? (data['barangay']['name'] as String)
            : (data['barangay'] as String?) ?? _statsUnknownBarangay;

        final isVerified = data['isVerified'] == true;
        final c = agg.putIfAbsent(b, () => _Counts());
        if (isVerified) {
          c.verified++;
        } else {
          c.unverified++;
        }
      }
      if (docs.length < _statsPageSize) {
        break;
      }
      cursor = docs.last;
    }

    if (scanned >= _statsMaxDocs) {
      debugPrint(
        'getUserStats reached defensive scan cap ($_statsMaxDocs docs); '
        'results may be incomplete.',
      );
    }

    _statsCache[cacheKey] = _CountsCacheEntry(counts: agg, fetchedAt: now);
    return agg;
  }
}

// small private helpers used only in this file
class _Counts {
  int verified = 0;
  int unverified = 0;
  int get total => verified + unverified;
}

class _CountsCacheEntry {
  final Map<String, _Counts> counts;
  final DateTime fetchedAt;

  const _CountsCacheEntry({required this.counts, required this.fetchedAt});
}
