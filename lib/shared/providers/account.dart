import 'package:flutter/foundation.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/services/account.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/utils/format/text.dart';

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
  String? _errorMessage;
  String _searchQuery = '';
  final List<UserRole> _roleFilters = [];
  final List<String> _statusFilters = [];
  String? _barangayFilter;

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

  /// Optional: preload actor names for visible users (call after loadUsers)
  void preloadActorNamesFor(List<UserDetails> users) {
    for (final u in users) {
      if (u.verifiedBy != null && !_actorNames.containsKey(u.verifiedBy)) {
        ensureActorName(u.verifiedBy!);
      }
      if (u.banBy != null && !_actorNames.containsKey(u.banBy)) {
        ensureActorName(u.banBy!);
      }
      if (u.unbannedBy != null && !_actorNames.containsKey(u.unbannedBy)) {
        ensureActorName(u.unbannedBy!);
      }
    }
  }

  List<UserDetails> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  List<UserRole> get roleFilters => _roleFilters;
  List<String> get statusFilters => _statusFilters;
  String? get barangayFilter => _barangayFilter;

  /// Load initial users
  Future<void> loadUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      List<UserRole>? effectiveRoleFilters = _roleFilters.isEmpty
          ? null
          : _roleFilters;
      List<String>? effectiveStatusFilters = _statusFilters.isEmpty
          ? null
          : _statusFilters;
      String? effectiveBarangayFilter = _barangayFilter;

      // Do NOT override here; service enforces admin scope. Keep filters only for sysadmin.
      if (_currentUser?.role == UserRole.admin) {
        effectiveRoleFilters = null; // ignored anyway
        effectiveBarangayFilter = null;
      }

      _users = await AccountService.instance.getUsers(
        roleFilters: effectiveRoleFilters,
        statusFilters: effectiveStatusFilters,
        barangayFilter: effectiveBarangayFilter,
        currentUser: _currentUser,
      );
      _prefetchAvatars(_users);
    } catch (e) {
      _errorMessage = 'Failed to load users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _prefetchAvatars(List<UserDetails> users) async {
    // Do not await; run in background but update map when done.
    for (final u in users) {
      if (u.selfiePath == null || u.selfiePath!.isEmpty) {
        _avatarUrls[u.userId] = null;
        continue;
      }
      // Kick off each request but don't block the UI thread
      ImageService.getDownloadUrlCached(u.selfiePath!)
          .then((url) {
            _avatarUrls[u.userId] = url;
            // Notify minimally to update visible items; consider batching if many
            notifyListeners();
          })
          .catchError((_) {
            _avatarUrls[u.userId] = null;
          });
    }
  }

  /// Search users
  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      await loadUsers();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      List<UserRole>? effectiveRoleFilters = _roleFilters.isEmpty
          ? null
          : _roleFilters;
      List<String>? effectiveStatusFilters = _statusFilters.isEmpty
          ? null
          : _statusFilters;
      String? effectiveBarangayFilter = _barangayFilter;

      if (_currentUser?.role == UserRole.admin) {
        effectiveRoleFilters = null;
        effectiveBarangayFilter = null;
      }

      _users = await AccountService.instance.searchUsers(
        query: query,
        roleFilters: effectiveRoleFilters,
        statusFilters: effectiveStatusFilters,
        barangayFilter: effectiveBarangayFilter,
        currentUser: _currentUser,
      );
      _prefetchAvatars(_users);
    } catch (e) {
      _errorMessage = 'Search failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  /// Apply current filters
  Future<void> _applyFilters() async {
    if (_searchQuery.trim().isNotEmpty) {
      await searchUsers(_searchQuery);
    } else {
      await loadUsers();
    }
  }

  /// Update user in list after action
  void updateUser(UserDetails updatedUser) {
    final index = _users.indexWhere((u) => u.userId == updatedUser.userId);
    if (index != -1) {
      _users[index] = updatedUser;
      notifyListeners();
    }
  }

  /// Remove user from list
  void removeUser(String userId) {
    _users.removeWhere((u) => u.userId == userId);
    notifyListeners();
  }
}
