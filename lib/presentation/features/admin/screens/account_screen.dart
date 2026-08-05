import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/providers/account.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/presentation/shared/widgets/search/search.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/features/admin/widgets/create_admin.dart';
import 'package:vcroad/presentation/features/admin/widgets/details.dart';
import 'package:vcroad/presentation/features/admin/widgets/lists.dart';
import 'package:vcroad/presentation/features/admin/widgets/badges.dart';
import 'package:vcroad/data/repositories/account.dart';
import 'package:vcroad/data/repositories/image.dart';
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/presentation/shared/widgets/search/barangay_filter.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/widgets/search/filter.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<SearchState> _searchKey = GlobalKey<SearchState>();
  bool _isLoading = false;
  bool _isDialogOpen = false;

  // Single shared barangay service instance reused by the inline filter UI.
  final BarangayService _barangayService = BarangayService();

  /// Clears the search field and all filters, cancelling any pending debounced
  /// search so a queued keystroke can't re-apply an old query afterwards.
  void _clearAllFilters() {
    _searchKey.currentState?.cancelPending();
    _searchController.clear();
    context.read<AccountProvider>().reset();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth/user provider so we react when the signed-in user changes.
    final signedInUser = context.watch<UserProvider>().user;

    // Defer side-effects to post-frame and only when the user actually changed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountProv = context.read<AccountProvider>();
      if (accountProv.currentUser?.userId != signedInUser?.userId) {
        accountProv.currentUser = signedInUser;
      }
      // Load users once per signed-in user (guards the initial double-fetch).
      if (signedInUser != null &&
          !accountProv.isInitialized &&
          !accountProv.isLoading) {
        accountProv.loadUsers();
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Account Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: context.responsive.scaleFont(18),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isDesktop ? 1100 : double.infinity,
          ),
          child: Column(
            children: [
              _buildSearchBar(),

              // --- INLINE filter area using BarangayFilter util (replaces local selector functions)
              Consumer<AccountProvider>(
                builder: (context, provider, _) {
                  final responsive = context.responsive;
                  final isAdmin = provider.currentUser?.role == UserRole.admin;

                  // Role chips
                  final roleChips = UserRole.values.map((role) {
                    final label = role == UserRole.sysadmin
                        ? 'Super Admin'
                        : role == UserRole.admin
                        ? 'Barangay Admin'
                        : 'Road User';
                    final color = role == UserRole.sysadmin
                        ? Colors.purple
                        : role == UserRole.admin
                        ? Colors.blue
                        : Colors.teal;
                    return Padding(
                      padding: EdgeInsets.only(right: context.scale(8)),
                      child: FilterChipButton(
                        responsive: responsive,
                        label: label,
                        icon: role == UserRole.sysadmin
                            ? Icons.security
                            : role == UserRole.admin
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        selected: provider.roleFilters.contains(role),
                        color: color,
                        onPressed: () => provider.toggleRoleFilter(role),
                      ),
                    );
                  }).toList();

                  // Status chips
                  final statusList = [
                    'verified',
                    'unverified',
                    'banned',
                    'inactive',
                    'flagged',
                  ];
                  final statusChips = statusList.map((status) {
                    final color = status == 'verified'
                        ? Colors.green
                        : status == 'banned'
                        ? Colors.red
                        : status == 'inactive'
                        ? Colors.amber
                        : status == 'flagged'
                        ? Colors.orange
                        : Colors.grey;
                    return Padding(
                      padding: EdgeInsets.only(right: context.scale(8)),
                      child: FilterChipButton(
                        responsive: responsive,
                        label: status == 'inactive'
                            ? 'Scheduled deletion'
                            : status[0].toUpperCase() + status.substring(1),
                        icon: Icons.label,
                        selected: provider.statusFilters.contains(status),
                        color: color,
                        onPressed: () => provider.toggleStatusFilter(status),
                      ),
                    );
                  }).toList();

                  return Container(
                    padding: EdgeInsets.all(context.scale(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: label + BarangayFilter + Clear All
                        Row(
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: context.scaleFont(16),
                              ),
                            ),
                            const Spacer(),

                            // Barangay filter util (button + dialog / sheet internally)
                            Builder(
                              builder: (ctx) {
                                final up = ctx.watch<UserProvider>();
                                final isAdminOnly =
                                    up.isAdmin && !up.isSysAdmin;
                                if (isAdminOnly) {
                                  final adminBarangayName =
                                      up.user?.barangay.name ?? 'N/A';
                                  // Ensure provider is scoped to admin barangay (defensive, runs after build)
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    final accProv = ctx.read<AccountProvider>();
                                    if (accProv.barangayFilter !=
                                        adminBarangayName) {
                                      accProv.setBarangayFilter(
                                        adminBarangayName,
                                      );
                                    }
                                  });

                                  return Builder(
                                    builder: (innerCtx) {
                                      final scheme = Theme.of(
                                        innerCtx,
                                      ).colorScheme;
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: context.scale(12),
                                          vertical: context.scale(8),
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: scheme.outline,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: context.scale(14),
                                              color: scheme.onSurfaceVariant,
                                            ),
                                            SizedBox(width: context.scale(8)),
                                            Text(
                                              adminBarangayName,
                                              style: TextStyle(
                                                fontSize: context.scaleFont(13),
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }

                                // Normal behavior for non-admins
                                return BarangayFilter(
                                  selected: provider.barangayFilter == null
                                      ? null
                                      : Barangay(
                                          name: provider.barangayFilter!,
                                        ),
                                  barangayService: _barangayService,
                                  selectLabel:
                                      provider.barangayFilter ??
                                      'Select Barangay',
                                  showClear: true,
                                  onChanged: (b) async {
                                    final name = b?.name;
                                    provider.setBarangayFilter(name);
                                  },
                                );
                              },
                            ),

                            SizedBox(width: context.scale(8)),
                            // Removed the "Clear All" button next to the barangay filter
                            // to keep the inline filter area minimal.
                          ],
                        ),

                        SizedBox(height: context.scale(12)),

                        // Chips area
                        if (context.isMobile)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                SizedBox(width: context.scale(8)),
                                if (!isAdmin) ...roleChips,
                                SizedBox(width: context.scale(8)),
                                ...statusChips,
                                SizedBox(width: context.scale(8)),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: context.scale(8),
                            runSpacing: context.scale(8),
                            children: [
                              if (!isAdmin) ...roleChips,
                              ...statusChips,
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),

              const Divider(height: 1),
              _buildFilterSummaryRow(),
              Expanded(child: _buildUserList()),
            ],
          ),
        ),
      ),

      // Floating add button — only visible to sysadmin. Uses responsive info to adapt style.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          // Only show FAB if current user is sysadmin
          if (!userProvider.isSysAdmin) return const SizedBox.shrink();

          return Builder(
            builder: (ctx) {
              final info = ctx.responsive;
              const tooltip = 'Add admin';
              // Use _isLoading to disable FAB while creating admin to avoid repeated calls.
              final isDisabled = _isLoading || _isDialogOpen;
              // On narrow screens use compact FAB, on wide screens use extended label
              if (info.isMobile) {
                return FloatingActionButton(
                  heroTag: 'fab_add_admin',
                  onPressed: isDisabled
                      ? null
                      : () => _showCreateAdminDialog(ctx),
                  tooltip: tooltip,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: isDisabled
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add),
                );
              }
              return FloatingActionButton.extended(
                heroTag: 'fab_add_admin',
                onPressed: isDisabled
                    ? null
                    : () => _showCreateAdminDialog(ctx),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: isDisabled
                    ? const SizedBox.shrink()
                    : const Icon(Icons.add),
                label: isDisabled
                    ? SizedBox(
                        width: 120,
                        height: 20,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      )
                    : const Text(
                        'Add admin',
                        style: TextStyle(color: Colors.white),
                      ),
                tooltip: tooltip,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterSummaryRow() {
    return Consumer<AccountProvider>(
      builder: (context, provider, _) {
        if (!provider.hasActiveFilters) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: context.scale(16),
            vertical: context.scale(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: context.scale(16),
                color: scheme.onSurfaceVariant,
              ),
              SizedBox(width: context.scale(8)),
              Expanded(
                child: Text(
                  'Showing ${provider.users.length} result'
                  '${provider.users.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: context.scaleFont(13),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserList() {
    return Consumer<AccountProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: context.scale(64),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: context.scale(16)),
                Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: context.scaleFont(14),
                  ),
                ),
                SizedBox(height: context.scale(16)),
                ElevatedButton(
                  onPressed: () => provider.loadUsers(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.users.isEmpty) {
          final filtered = provider.hasActiveFilters;
          final searching = provider.searchQuery.trim().isNotEmpty;
          final scheme = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filtered ? Icons.search_off : Icons.people_outline,
                  size: context.scale(64),
                  color: scheme.onSurfaceVariant,
                ),
                SizedBox(height: context.scale(16)),
                Text(
                  filtered
                      ? (searching
                            ? 'Nothing matched "${provider.searchQuery.trim()}"'
                            : 'No users match the current filters')
                      : 'No users yet',
                  style: TextStyle(
                    fontSize: context.scaleFont(18),
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (filtered) ...[
                  SizedBox(height: context.scale(8)),
                  Text(
                    searching
                        ? 'Try a different name, email, street, or barangay.'
                        : 'Try adjusting or clearing your filters.',
                    style: TextStyle(
                      fontSize: context.scaleFont(13),
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.scale(12)),
                  OutlinedButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Clear filters'),
                  ),
                ],
              ],
            ),
          );
        }

        if (context.isDesktop) {
          return _buildDenseTable(context, provider);
        }

        final loadingMore = provider.isLoadingMore && provider.hasMore
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : null;

        return RefreshIndicator(
          onRefresh: () => provider.loadUsers(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                context.read<AccountProvider>().loadMore();
              }
              return false;
            },
            child: ListView.builder(
              itemCount: provider.users.length + (loadingMore != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (loadingMore != null && index == provider.users.length) {
                  return loadingMore;
                }
                final user = provider.users[index];
                final avatarUrl = provider.avatarUrls[user.userId];
                return UserListItem(
                  key: ValueKey(user.userId),
                  user: user,
                  avatarUrl: avatarUrl,
                  onTap: () => _navigateToDetails(user),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Dense, scannable account table for wide (desktop) layouts. Columns collapse
  /// on narrower screens via horizontal scrolling; each row opens account details.
  Widget _buildDenseTable(BuildContext context, AccountProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final rows = provider.users;

    final columns = <DataColumn>[
      DataColumn(
        label: Text('User', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      DataColumn(
        label: Text('Barangay', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      const DataColumn(label: Text('Role')),
      const DataColumn(label: Text('Status')),
      const DataColumn(label: Text('Flagged'), numeric: true),
    ];

    final dataRows = <DataRow>[
      for (final user in rows)
        DataRow(
          onSelectChanged: (_) => _navigateToDetails(user),
          cells: [
            DataCell(
              Row(
                children: [
                  ImageService.buildCachedAvatar(
                    imageUrl: provider.avatarUrls[user.userId],
                    radius: context.scale(18),
                    cacheWidth: context.cacheWidthForImage(context.scale(36)),
                  ),
                  SizedBox(width: context.scale(12)),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: context.scaleFont(14),
                          ),
                        ),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: context.scaleFont(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            DataCell(
              Text(
                user.barangay.name.replaceAll('_', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: context.scaleFont(13),
                ),
              ),
            ),
            DataCell(RoleBadge(role: user.role)),
            DataCell(StatusBadge.fromUser(user)),
            DataCell(
              user.flaggedReportsCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${user.flaggedReportsCount}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: context.scaleFont(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Text('—', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scrollable = DataTable(
          columnSpacing: context.scale(28),
          headingRowHeight: context.scale(44),
          dataRowMinHeight: context.scale(56),
          dataRowMaxHeight: context.scale(64),
          horizontalMargin: context.scale(16),
          headingRowColor: WidgetStatePropertyAll(
            scheme.surfaceContainerHighest,
          ),
          columns: columns,
          rows: dataRows,
        );

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
              context.read<AccountProvider>().loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () => provider.loadUsers(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: scrollable,
                    ),
                  ),
                  if (provider.isLoadingMore && provider.hasMore)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      child: Search(
        key: _searchKey,
        controller: _searchController,
        hint: 'Search by name, email, street, barangay...',
        debounceDuration: const Duration(milliseconds: 300),
        onSearch: (q) => context.read<AccountProvider>().searchUsers(q),
      ),
    );
  }

  void _navigateToDetails(UserDetails user) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AccountDetailsPage(user: user)));
  }

  Future<void> _showCreateAdminDialog(BuildContext ctx) async {
    // Guard against opening duplicate dialogs on rapid taps.
    if (_isDialogOpen) return;
    _isDialogOpen = true;

    final Map<String, dynamic>? result;
    try {
      result = await showDialog<Map<String, dynamic>>(
        context: ctx,
        builder: (_) => const CreateAdminDialog(),
      );
    } finally {
      _isDialogOpen = false;
    }

    if (result == null || !ctx.mounted) return;

    final createdBy =
        ctx.read<AccountProvider>().currentUser?.userId ??
        ctx.read<UserProvider>().user?.userId;
    if (createdBy == null || createdBy.isEmpty) {
      if (ctx.mounted) {
        SnackbarUtils.showError(ctx, 'Unable to resolve your account.');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AccountService.instance.createAdminAccount(
        email: result['email'] as String? ?? '',
        password: result['password'] as String? ?? '',
        userDetails:
            (result['userDetails'] as Map<String, dynamic>?) ?? const {},
        barangay:
            (((result['userDetails'] as Map<String, dynamic>?) ?? const {})
                    .cast<String, dynamic>()['barangay']
                as Map<String, dynamic>?) ??
            const {},
        createdBy: createdBy,
      );

      if (!ctx.mounted) return;

      SnackbarUtils.showSuccess(ctx, 'Barangay Admin account created.');

      // Reset scope/query so the new account reflects the latest list.
      _searchKey.currentState?.cancelPending();
      _searchController.clear();
      ctx.read<AccountProvider>().reset();
    } on FirebaseAuthException catch (e) {
      if (!ctx.mounted) return;
      // Show a friendly message for email conflicts.
      SnackbarUtils.showError(
        ctx,
        e.code == 'email-already-in-use'
            ? 'That email is already registered. Use a different email.'
            : (e.message ?? 'Failed to create the admin account.'),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      SnackbarUtils.showError(ctx, 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
