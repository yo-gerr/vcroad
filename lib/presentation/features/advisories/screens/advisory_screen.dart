import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vcroad/data/repositories/advisory_export.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/web/web_download.dart' as web_download;
import 'package:vcroad/presentation/shared/dialogs/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/presentation/providers/advisory.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/presentation/shared/dialogs/advisory.dart';
import 'package:vcroad/presentation/shared/dialogs/confirmation.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/widgets/search/search.dart';
import 'package:vcroad/presentation/features/advisories/widgets/create_advisory.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/shared/widgets/search/filter.dart';
import 'package:vcroad/presentation/shared/widgets/search/barangay_filter.dart';
import 'package:vcroad/presentation/shared/widgets/stats/stats.dart';
import 'package:vcroad/presentation/features/advisories/widgets/advisory_list_view.dart';

class AdvisoryScreen extends StatefulWidget {
  const AdvisoryScreen({super.key});

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  final _searchController = TextEditingController();
  // Keyed so "Clear search & filters" can cancel any pending debounced search
  // before resetting, preventing a stale query from re-applying.
  final GlobalKey<SearchState> _searchKey = GlobalKey<SearchState>();
  // Single shared BarangayService instance reused by the BarangayFilter to
  // avoid duplicate loads and keep a single cache.
  final BarangayService _barangayService = BarangayService();
  Barangay? _selectedBarangay; // null => no filter (was "All Barangays")

  // Cap the admin/sysadmin all-statuses stream so it doesn't download the full
  // historical backlog (ordered newest-first, so older docs drop off).
  static const int _adminStreamLimit = 200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Don't call into context if this widget was removed before the frame.
      if (!mounted) return;
      _loadAdvisories();
    });

    // Ensure barangays are loaded for the BarangayFilter.
    // loadBarangays is safe to call multiple times; it guards against duplicate loads.
    _barangayService
        .loadBarangays()
        .then((_) {
          if (!mounted) return;
          setState(() {}); // refresh so the filter shows loaded options
        })
        .catchError((e, st) {
          debugPrint('Barangay load error: $e\n$st');
        });
    // Note: BarangayFilter also attempts to load/cached data, but pre-loading improves UX.
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdvisories() async {
    final provider = context.read<AdvisoryProvider>();
    final userProvider = context.read<UserProvider>();

    // Regular users share the app-level consolidated stream (active + scheduled,
    // all barangays) that also powers the home map and new-advisory alerts.
    if (userProvider.role == UserRole.user) {
      await provider.startUserStream();
      return;
    }

    // Admin/sysadmin: stream all statuses, capped to the latest N for performance.
    if (userProvider.isAdmin &&
        !userProvider.isSysAdmin &&
        userProvider.user?.barangay != null) {
      _selectedBarangay = userProvider.user!.barangay;
      await provider.startAdvisoryStream(
        barangay: userProvider.user!.barangay.name,
        useRealtime: true,
        initialFilter: provider.currentFilter,
        statuses: null,
        limit: _adminStreamLimit,
      );
    } else {
      await provider.startAdvisoryStream(
        barangay: _selectedBarangay?.name,
        useRealtime: true,
        initialFilter: provider.currentFilter,
        statuses: null,
        limit: _adminStreamLimit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final userProvider = context.watch<UserProvider>();
    // Role-aware title: sysadmin > admin > regular user
    final titleText = userProvider.isSysAdmin
        ? 'System Advisory Management'
        : userProvider.isAdmin
        ? 'Advisory Management'
        : 'Traffic Advisories';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          titleText,
          style: TextStyle(
            color: Colors.white,
            fontSize: responsive.scaleFont(18),
          ),
        ),
      ),
      // Center content and constrain max width on wide screens like the Lesson page.
      // Use the same max width pattern so content reads comfortably on web/desktop.
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // match Lesson pattern: generous max width on desktop, else use responsive max
            maxWidth: responsive.isDesktop ? 1100 : responsive.maxFormWidth,
          ),
          child: SafeArea(child: _buildAdvisoryList(responsive)),
        ),
      ),
      // Floating action button for creating advisories (use unique heroTag)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Builder(
        builder: (ctx) {
          if (!(userProvider.isAdmin || userProvider.isSysAdmin)) {
            return const SizedBox.shrink();
          }

          final info = ctx.responsive;
          const tooltip = 'Create Advisory';

          if (info.isMobile) {
            return FloatingActionButton(
              heroTag: 'fab_create_advisory',
              onPressed: () => _navigateToCreate(ctx),
              tooltip: tooltip,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          }

          return FloatingActionButton.extended(
            heroTag: 'fab_create_advisory',
            onPressed: () => _navigateToCreate(ctx),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(
              'Create Advisory',
              style: TextStyle(
                fontSize: info.scaleFont(14),
                color: Colors.white,
              ),
            ),
            tooltip: tooltip,
          );
        },
      ),
    );
  }

  Widget _buildAdvisoryList(dynamic responsive) {
    return Consumer<AdvisoryProvider>(
      builder: (context, provider, _) {
        final userProv = context.watch<UserProvider>();
        final hideStatsForUser = userProv.role == UserRole.user;
        final canEdit = userProv.isAdmin || userProv.isSysAdmin;

        // A non-sysadmin admin's barangay is forced by their account; it is NOT
        // an active filter, so exclude it from the "filters active" signal.
        final isAdminOnly = userProv.isAdmin && !userProv.isSysAdmin;
        final forcedBarangay = isAdminOnly && _selectedBarangay != null;
        final hasActiveFilters =
            _searchController.text.trim().isNotEmpty ||
            (!forcedBarangay && _selectedBarangay != null) ||
            provider.currentFilter != AdvisoryViewFilter.all;

        return Column(
          children: [
            // Top stats cards (hidden for normal users)
            // Add consistent top spacing like Lesson screen so stats aren't flush to the top.
            if (!hideStatsForUser)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.scale(16),
                  vertical: responsive.scale(16),
                ),
                child: _buildTopStats(responsive, provider),
              ),
            // Search and Filter Bar
            _buildSearchAndFilter(responsive, provider),
            const Divider(height: 1),

            // Advisory Cards
            Expanded(
              child: AdvisoryListView(
                responsive: responsive,
                isLoading: provider.isLoading,
                error: provider.error,
                advisories: provider.filteredAdvisories,
                canEdit: canEdit,
                showCreateCta: canEdit,
                onRetry: _loadAdvisories,
                onCreate: () => _navigateToCreate(context),
                onShowDetails: _showAdvisoryDetails,
                onDelete: _deleteAdvisory,
                onDownload: _downloadAdvisory,
                onEdit: (a) => _navigateToEdit(context, a),
                onToggleStatus: _toggleStatus,
                onRefresh: provider.refresh,
                hasAnyData: provider.advisories.isNotEmpty,
                hasActiveFilters: hasActiveFilters,
                searchQuery: _searchController.text.trim(),
                onClearFilters: _clearFilters,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopStats(dynamic responsive, AdvisoryProvider provider) {
    final all = provider.advisories;
    final total = all.length;
    final scheduled = all
        .where((a) => a.status == AdvisoryStatus.scheduled)
        .length;
    final activeNow = all
        .where((a) => a.status == AdvisoryStatus.active)
        .length;
    final inactive = all
        .where((a) => a.status == AdvisoryStatus.inactive)
        .length;
    final expired = all.where((a) => a.status == AdvisoryStatus.expired).length;

    // Stats are a read-only summary — filtering is done via the chips below so
    // there is a single, discoverable filter control.
    final stats = [
      StatsUtils(
        label: 'Total',
        value: total.toString(),
        icon: Icons.list,
        color: AppColors.primaryAdaptive(context),
      ),
      StatsUtils(
        label: 'Scheduled',
        value: scheduled.toString(),
        icon: Icons.schedule,
        color: AdvisoryStatus.scheduled.color,
      ),
      StatsUtils(
        label: 'Active',
        value: activeNow.toString(),
        icon: Icons.play_circle_filled,
        color: AdvisoryStatus.active.color,
      ),
      StatsUtils(
        label: 'Inactive',
        value: inactive.toString(),
        icon: Icons.pause,
        color: AdvisoryStatus.inactive.color,
      ),
      StatsUtils(
        label: 'Expired',
        value: expired.toString(),
        icon: Icons.history,
        color: AdvisoryStatus.expired.color,
      ),
    ];

    // Use the reusable StatsRow which adapts layout for mobile/tablet/desktop.
    return StatsRow(stats: stats, responsive: responsive);
  }

  Widget _buildSearchAndFilter(dynamic responsive, AdvisoryProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final primaryAccent = AppColors.primaryAdaptive(context);
    return Container(
      padding: EdgeInsets.all(responsive.scale(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar on top
          Search(
            key: _searchKey,
            controller: _searchController,
            debounceDuration: const Duration(milliseconds: 300),
            hint: 'Search by address...',
            onSearch: (q) => provider.searchAdvisories(q),
            onClear: () => provider.searchAdvisories(''),
          ),
          SizedBox(height: responsive.scale(12)),
          // Row: Filter label + sort + refresh (left) and barangay selector
          // badge/button (right). Wrap so the right group falls to a second
          // line instead of overflowing on narrow screens.
          Wrap(
            spacing: responsive.scale(8),
            runSpacing: responsive.scale(8),
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Left-aligned label
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: responsive.scaleFont(16),
                    ),
                  ),
                  SizedBox(width: responsive.scale(4)),
                  // Sort control: labeled so the active ordering is always visible
                  PopupMenuButton<AdvisorySortOrder>(
                    tooltip: 'Sort advisories',
                    onSelected: (order) => provider.setSortOrder(order),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: AdvisorySortOrder.newest,
                        child: _buildSortItem(
                          'Newest',
                          provider.sortOrder == AdvisorySortOrder.newest,
                        ),
                      ),
                      PopupMenuItem(
                        value: AdvisorySortOrder.oldest,
                        child: _buildSortItem(
                          'Oldest',
                          provider.sortOrder == AdvisorySortOrder.oldest,
                        ),
                      ),
                      PopupMenuItem(
                        value: AdvisorySortOrder.recentlyUpdated,
                        child: _buildSortItem(
                          'Recently updated',
                          provider.sortOrder ==
                              AdvisorySortOrder.recentlyUpdated,
                        ),
                      ),
                    ],
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.scale(10),
                        vertical: responsive.scale(8),
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_vert,
                            size: responsive.scale(16),
                            color: primaryAccent,
                          ),
                          SizedBox(width: responsive.scale(6)),
                          Text(
                            _sortLabel(provider.sortOrder),
                            style: TextStyle(
                              fontSize: responsive.scaleFont(13),
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.scale(8)),
                  // Manual refresh (pull-to-refresh handles mobile; desktop needs this)
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => provider.refresh(),
                    icon: Icon(
                      Icons.refresh,
                      size: responsive.scale(20),
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              // Right-aligned group: use reusable BarangayFilter widget.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // If admin (not sysadmin) show read-only barangay badge and force stream/filter.
                  Builder(
                    builder: (ctx) {
                      final up = ctx.watch<UserProvider>();
                      final isAdminOnly = up.isAdmin && !up.isSysAdmin;
                      if (isAdminOnly) {
                        final adminBarangay = up.user?.barangay.name ?? 'N/A';
                        final badgeScheme = Theme.of(ctx).colorScheme;
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.scale(12),
                            vertical: responsive.scale(8),
                          ),
                          decoration: BoxDecoration(
                            color: badgeScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: badgeScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: responsive.scale(14),
                                color: badgeScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: responsive.scale(8)),
                              Text(
                                adminBarangay,
                                style: TextStyle(
                                  fontSize: responsive.scaleFont(13),
                                  color: badgeScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Non-admins keep interactive BarangayFilter.
                      return BarangayFilter(
                        selected: _selectedBarangay,
                        barangayService: _barangayService,
                        selectLabel: 'Select Barangay',
                        showClear: true,
                        onChanged: (b) async {
                          setState(() => _selectedBarangay = b);
                          final userRole = context.read<UserProvider>().role;
                          if (userRole == UserRole.user) {
                            // Regular users filter client-side over the shared
                            // consolidated stream (no stream restart needed).
                            provider.applyFilter(
                              b == null
                                  ? AdvisoryViewFilter.all
                                  : AdvisoryViewFilter.byBarangay,
                              barangay: b?.name,
                            );
                            return;
                          }
                          await provider.startAdvisoryStream(
                            barangay: b?.name,
                            useRealtime: true,
                            initialFilter: provider.currentFilter,
                            statuses: null,
                            limit: _adminStreamLimit,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: responsive.scale(12)),
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Builder(
              builder: (ctx) {
                final userRole = ctx.watch<UserProvider>().role;
                final hideAdminOnlyFilters = userRole == UserRole.user;
                return Row(
                  children: [
                    // Reusable, consistent filter chips (soft background tint + colored border)
                    FilterChipButton(
                      responsive: responsive,
                      label: 'All',
                      icon: Icons.list,
                      selected:
                          provider.currentFilter == AdvisoryViewFilter.all,
                      color: Colors.grey.shade800,
                      onPressed: () => provider.applyFilter(
                        AdvisoryViewFilter.all,
                        barangay: _selectedBarangay?.name,
                      ),
                    ),
                    SizedBox(width: responsive.scale(8)),
                    FilterChipButton(
                      responsive: responsive,
                      label: 'Active',
                      icon: Icons.play_circle_filled,
                      selected:
                          provider.currentFilter == AdvisoryViewFilter.active,
                      color: Colors.green.shade700,
                      onPressed: () => provider.applyFilter(
                        AdvisoryViewFilter.active,
                        barangay: _selectedBarangay?.name,
                      ),
                    ),
                    SizedBox(width: responsive.scale(8)),
                    FilterChipButton(
                      responsive: responsive,
                      label: 'Scheduled',
                      icon: Icons.schedule,
                      selected:
                          provider.currentFilter ==
                          AdvisoryViewFilter.scheduled,
                      color: Colors.orange.shade800,
                      onPressed: () => provider.applyFilter(
                        AdvisoryViewFilter.scheduled,
                        barangay: _selectedBarangay?.name,
                      ),
                    ),
                    if (!hideAdminOnlyFilters) ...[
                      SizedBox(width: responsive.scale(8)),
                      FilterChipButton(
                        responsive: responsive,
                        label: 'Inactive',
                        icon: Icons.pause,
                        selected:
                            provider.currentFilter ==
                            AdvisoryViewFilter.inactive,
                        color: Colors.red.shade700,
                        onPressed: () => provider.applyFilter(
                          AdvisoryViewFilter.inactive,
                          barangay: _selectedBarangay?.name,
                        ),
                      ),
                      SizedBox(width: responsive.scale(8)),
                      FilterChipButton(
                        responsive: responsive,
                        label: 'Expired',
                        icon: Icons.history,
                        selected:
                            provider.currentFilter ==
                            AdvisoryViewFilter.expired,
                        color: Colors.grey.shade700,
                        onPressed: () => provider.applyFilter(
                          AdvisoryViewFilter.expired,
                          barangay: _selectedBarangay?.name,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(AdvisorySortOrder order) {
    return switch (order) {
      AdvisorySortOrder.newest => 'Newest',
      AdvisorySortOrder.oldest => 'Oldest',
      AdvisorySortOrder.recentlyUpdated => 'Recently updated',
    };
  }

  Widget _buildSortItem(String label, bool selected) {
    return Row(
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 18,
          color: selected ? AppColors.primaryAdaptive(context) : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Reset search, barangay, and status filters. A non-sysadmin admin's
  /// barangay is account-scoped so it is preserved.
  void _clearFilters() {
    // Cancel any pending debounced search so a stale keystroke can't re-apply
    // after the field is cleared.
    _searchKey.currentState?.cancelPending();
    _searchController.clear();
    final provider = context.read<AdvisoryProvider>();
    final userProvider = context.read<UserProvider>();
    final role = userProvider.role;

    if (role == UserRole.user) {
      setState(() => _selectedBarangay = null);
      provider.applyFilter(AdvisoryViewFilter.all, barangay: null);
    } else if (userProvider.isSysAdmin) {
      setState(() => _selectedBarangay = null);
      provider.applyFilter(AdvisoryViewFilter.all, barangay: null);
      // Re-scope the stream back to all barangays.
      provider.startAdvisoryStream(
        barangay: null,
        useRealtime: true,
        initialFilter: AdvisoryViewFilter.all,
        statuses: null,
        limit: _adminStreamLimit,
      );
    } else {
      // Non-sysadmin admin: reset only the status filter.
      provider.applyFilter(
        AdvisoryViewFilter.all,
        barangay: _selectedBarangay?.name,
      );
    }
    provider.searchAdvisories('');
  }

  /// Quick Activate / Deactivate toggle. The provider re-saves the doc with
  /// the new persisted status (version bumped); no manual re-save needed.
  Future<void> _toggleStatus(Advisory advisory) async {
    final provider = context.read<AdvisoryProvider>();
    final success = await provider.toggleAdvisoryStatus(advisory.advisoryId);

    if (!mounted) return;
    if (success) {
      final activated = advisory.status != AdvisoryStatus.active;
      SnackbarUtils.showSuccess(
        context,
        'Advisory ${activated ? 'activated' : 'deactivated'}',
      );
    } else {
      SnackbarUtils.showError(context, 'Status update failed');
    }
  }

  void _showAdvisoryDetails(Advisory advisory) {
    try {
      AdvisoryDetailsDialog.show(context, advisory);
    } catch (e) {
      final msg = e.toString();
      // Known google_maps_flutter error when native map not yet ready.
      if (msg.contains('Maps cannot be retrieved before calling buildView')) {
        // Schedule to open after the current frame so the map can initialize.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            AdvisoryDetailsDialog.show(context, advisory);
          } catch (_) {
            // second attempt failed — fail silently to avoid crashing the app.
          }
        });
        return;
      }
      // Unknown error — rethrow so it surfaces in debug/build logs.
      rethrow;
    }
  }

  Future<void> _navigateToCreate(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateAdvisory()),
    );

    if (result == true) {
      _loadAdvisories();
    }
  }

  Future<void> _navigateToEdit(BuildContext context, Advisory advisory) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAdvisory(existingAdvisory: advisory),
      ),
    );

    if (result == true) {
      _loadAdvisories();
    }
  }

  Future<void> _deleteAdvisory(Advisory advisory) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmationDialog(
        title: 'Delete Advisory?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<AdvisoryProvider>();
      final success = await provider.deleteAdvisory(advisory.advisoryId);

      if (!mounted) return;
      if (success) {
        SnackbarUtils.showSuccess(context, 'Advisory deleted');
      } else {
        SnackbarUtils.showError(context, 'Delete failed');
      }
    }
  }

  Future<void> _downloadAdvisory(Advisory advisory) async {
    // Show blocking loading indicator while image is generated
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Generating image...'),
    );

    try {
      if (kIsWeb) {
        // Generate bytes and open in new tab via blob URL
        final bytes = await AdvisoryExportService.instance
            .generateAdvisoryImageBytes(advisory, width: 1200, height: 630);
        if (!mounted) return;
        Navigator.of(context).pop(); // close loading
        web_download.openBytesInNewTab(
          bytes,
          'advisory_${advisory.advisoryId}.png',
        );
        SnackbarUtils.showSuccess(context, 'Image opened in a new tab');
        return;
      }

      // Native platforms: generate file and show snackbar with Open action
      final file = await AdvisoryExportService.instance.generateAdvisoryImage(
        advisory,
        width: 1200,
        height: 630,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      SnackbarUtils.show(
        context,
        'Image saved to temp: ${file.path}',
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () async {
            final uri = Uri.file(file.path).toString();
            await launchUrlString(uri);
          },
        ),
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // ensure loading closed
        SnackbarUtils.showError(context, 'Export failed: $e');
      }
    }
  }
}
