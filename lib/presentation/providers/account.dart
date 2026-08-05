import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/data/repositories/account.dart';
import 'package:vcroad/core/utils/format/text.dart';

class AccountProvider extends ChangeNotifier {
  // Add currentUser property (set this on login)
  UserDetails? _currentUser;
  UserDetails? get currentUser => _currentUser;
  set currentUser(UserDetails? user) {
    _currentUser = user;
    notifyListeners();
  }

  List<UserDetails> _users = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _searchQuery = '';
  final List<UserRole> _roleFilters = [];
  final List<String> _statusFilters = [];
  String? _barangayFilter;

  // Pagination state
  static const int _pageSize = 20;
  DocumentSnapshot? _cursor;
  bool _hasMore = true;
  bool _initialized = false;

  // Increments on every first-page reload; stale responses are discarded.
  int _listSeq = 0;

  // New: avatar cache map (userId -> downloadUrl)
  final Map<String, String?> _avatarUrls = {};
  Map<String, String?> get avatarUrls => _avatarUrls;

  // Actor name cache (userId -> displayName)
  final Map<String, String> _actorNames = {};
  final Set<String> _actorFetchInProgress = {};

  String? getActorDisplayName(String userId) => _actorNames[userId];

  String getActorDisplayNameOrId(String? userId) {
    if (userId == null || userId.isEmpty) return '—';
    return _actorNames[userId] ?? userId;
  }

  /// Ensure actor name is loaded. If already loading or cached, returns immediately.
  /// When fetch completes provider notifies listeners to update UI.
  Future<void> ensureActorName(String userId) async {
    if (userId.isEmpty) return;
    if (_actorNames.containsKey(userId)) return;
    if (_actorFetchInProgress.contains(userId)) return;

    _actorFetchInProgress.add(userId);
    try {
      final user = await AccountService.instance.getUserById(userId);
      if (user != null) {
        final parts = <String>[];
        if ((user.firstName).isNotEmpty) parts.add(user.firstName.trim());
        if ((user.middleName ?? '').isNotEmpty) {
          parts.add(user.middleName!.trim());
        }
        if ((user.lastName).isNotEmpty) parts.add(user.lastName.trim());
        final joined = parts.join(' ').trim();
        _actorNames[userId] = joined.isEmpty
            ? userId
            : TextFormat.titleCase(joined);
      } else {
        _actorNames[userId] = userId;
      }
    } catch (_) {
      _actorNames[userId] = userId;
    } finally {
      _actorFetchInProgress.remove(userId);
      notifyListeners();
    }
  }

  List<UserDetails> get users => _users;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  List<UserRole> get roleFilters => _roleFilters;
  List<String> get statusFilters => _statusFilters;
  String? get barangayFilter => _barangayFilter;

  /// True once the initial user load has completed on this provider instance.
  bool get isInitialized => _initialized;

  /// Reloads the first page of users (clears any accumulated results/cursor).
  /// A sequence token discards stale responses so rapid search/filter changes
  /// never let an older (slower) query overwrite the latest results.
  Future<void> loadUsers() async {
    final seq = ++_listSeq;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _fetchUsersPage(startOver: true);
      if (seq == _listSeq) {
        _users = page.users;
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _initialized = true;
      }
    } catch (e) {
      if (seq == _listSeq) {
        _errorMessage = 'Unable to load users. Please try again.';
        debugPrint('AccountProvider.loadUsers failed: $e');
      }
    } finally {
      if (seq == _listSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Appends the next page of results for infinite scroll.
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final seq = _listSeq;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _fetchUsersPage();
      if (seq == _listSeq) {
        _users.addAll(page.users);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        notifyListeners();
      }
    } catch (_) {
      // Silently stop pagination on error; hasMore stays so a retry may work.
    } finally {
      if (seq == _listSeq) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<({List<UserDetails> users, DocumentSnapshot? cursor, bool hasMore})>
  _fetchUsersPage({bool startOver = false}) async {
    if (!startOver && _cursor == null) {
      return (users: const <UserDetails>[], cursor: null, hasMore: false);
    }

    final effectiveRole = _effectiveRoleFilters();
    final effectiveStatus = _effectiveStatusFilters();
    final effectiveBarangay = _effectiveBarangayFilter();

    final isSearching = _searchQuery.trim().isNotEmpty;
    if (isSearching) {
      return await AccountService.instance.searchUsers(
        query: _searchQuery,
        roleFilters: effectiveRole,
        statusFilters: effectiveStatus,
        barangayFilter: effectiveBarangay,
        hitsPerPage: _pageSize,
        startAfter: startOver ? null : _cursor,
        currentUser: _currentUser,
      );
    }

    return await AccountService.instance.getUsers(
      limit: _pageSize,
      startAfter: startOver ? null : _cursor,
      roleFilters: effectiveRole,
      statusFilters: effectiveStatus,
      barangayFilter: effectiveBarangay,
      currentUser: _currentUser,
    );
  }

  List<UserRole>? _effectiveRoleFilters() {
    if (_currentUser?.role == UserRole.admin) return null;
    return _roleFilters.isEmpty ? null : _roleFilters;
  }

  List<String>? _effectiveStatusFilters() =>
      _statusFilters.isEmpty ? null : List.of(_statusFilters);

  String? _effectiveBarangayFilter() {
    if (_currentUser?.role == UserRole.admin) return null;
    return _barangayFilter;
  }

  /// Whether any filter/search is currently narrowing the visible list.
  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _roleFilters.isNotEmpty ||
      _statusFilters.isNotEmpty ||
      _barangayFilter != null;

  /// Sets the active search query and reloads the first page.
  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    await loadUsers();
  }

  /// Toggle role filter
  void toggleRoleFilter(UserRole role) {
    if (_currentUser?.role == UserRole.admin) {
      return; // admins cannot alter role scope
    }
    if (_roleFilters.contains(role)) {
      _roleFilters.remove(role);
    } else {
      _roleFilters.add(role);
    }
    _applyFilters();
  }

  /// Toggle a status filter and re-apply the scoped search.
  /// Allowed statuses: verified, unverified, banned, inactive, flagged
  void toggleStatusFilter(String status) {
    const allowed = {'verified', 'unverified', 'banned', 'inactive', 'flagged'};
    if (!allowed.contains(status)) return;

    if (_statusFilters.contains(status)) {
      _statusFilters.remove(status);
    } else {
      _statusFilters.add(status);
    }
    _applyFilters(); // Service enforces admin scope (role=user + same barangay)
  }

  void setBarangayFilter(String? barangayName) {
    if (_currentUser?.role == UserRole.admin) {
      return; // admins cannot change barangay scope
    }
    _barangayFilter = (barangayName?.isEmpty ?? true) ? null : barangayName;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _statusFilters.clear();
    if (_currentUser?.role != UserRole.admin) {
      _roleFilters.clear();
      _barangayFilter = null;
    }
    _applyFilters();
  }

  /// Reset everything (query + filters) back to the unfiltered list.
  void reset() {
    _searchQuery = '';
    _statusFilters.clear();
    if (_currentUser?.role != UserRole.admin) {
      _roleFilters.clear();
      _barangayFilter = null;
    }
    _applyFilters();
  }

  /// Apply current filter/query state by reloading the first page.
  Future<void> _applyFilters() async {
    await loadUsers();
  }

  /// Update user in list after action
  void updateUser(UserDetails updatedUser) {
    final index = _users.indexWhere((u) => u.userId == updatedUser.userId);
    if (index != -1) {
      _users[index] = updatedUser;
      notifyListeners();
    }
  }
}
