import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vcroad_v2/shared/services/advisory_export.dart';
import 'package:vcroad_v2/shared/utils/web/web_download.dart' as web_download;
import 'package:vcroad_v2/shared/utils/dialog/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/advisory.dart';
import 'package:vcroad_v2/shared/providers/advisory.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/utils/dialog/advisory.dart';
import 'package:vcroad_v2/shared/utils/dialog/confirmation.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/search/search.dart';
import 'package:vcroad_v2/shared/widgets/advisory/create_advisory.dart';
import 'package:vcroad_v2/shared/utils/format/date_time.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/utils/search/filter.dart';
import 'package:vcroad_v2/shared/utils/search/barangay_filter.dart';
import 'package:vcroad_v2/shared/utils/stats/stats.dart';

class AdvisoryScreen extends StatefulWidget {
  const AdvisoryScreen({super.key});

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  final _searchController = TextEditingController();
  // Single shared BarangayService instance reused by the BarangayFilter to
  // avoid duplicate loads and keep a single cache.
  final BarangayService _barangayService = BarangayService();
  Barangay? _selectedBarangay; // null => no filter (was "All Barangays")

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

    // Decide which statuses to stream based on role:
    // - normal user: only active + scheduled
    // - admin/sysadmin: all statuses (null => no restriction)
    List<AdvisoryStatus>? statuses;
    if (userProvider.role == UserRole.user) {
      statuses = [AdvisoryStatus.active, AdvisoryStatus.scheduled];
    } else {
      statuses = null;
    }

    // userProvider.user?.barangay is a Barangay object — pass the name (String)
    // If admin (but not sysadmin) restrict stream to their barangay for performance and data privacy.
    if (userProvider.isAdmin &&
        !userProvider.isSysAdmin &&
        userProvider.user?.barangay != null) {
      _selectedBarangay = userProvider.user!.barangay;
      await provider.startAdvisoryStream(
        barangay: userProvider.user!.barangay.name,
        useRealtime: true,
        initialFilter: provider.currentFilter,
        statuses: statuses,
      );
    } else {
      await provider.startAdvisoryStream(
        barangay: _selectedBarangay?.name,
        useRealtime: true,
        initialFilter: provider.currentFilter,
        statuses: statuses,
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
        backgroundColor: const Color(0xFF001278),
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
              backgroundColor: const Color(0xFF001278),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          }

          return FloatingActionButton.extended(
            heroTag: 'fab_create_advisory',
            onPressed: () => _navigateToCreate(ctx),
            backgroundColor: const Color(0xFF001278),
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

            // Advisory Count Stats
            if (provider.filteredAdvisories.isNotEmpty)
              _buildStatsBar(responsive, provider),

            // Advisory Cards
            Expanded(child: _buildAdvisoryCards(responsive, provider)),
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

    final stats = [
      StatsUtils(
        label: 'Total',
        value: total.toString(),
        icon: Icons.list,
        color: const Color(0xFF001278),
      ),
      StatsUtils(
        label: 'Scheduled',
        value: scheduled.toString(),
        icon: Icons.schedule,
        color: Colors.orange,
      ),
      StatsUtils(
        label: 'Active',
        value: activeNow.toString(),
        icon: Icons.play_circle_filled,
        color: Colors.green,
      ),
      StatsUtils(
        label: 'Inactive',
        value: inactive.toString(),
        icon: Icons.pause,
        color: Colors.red, // changed: inactive -> red
      ),
      StatsUtils(
        label: 'Expired',
        value: expired.toString(),
        icon: Icons.history,
        color: Colors.grey, // changed: expired -> grey
      ),
    ];

    // Use the reusable StatsRow which adapts layout for mobile/tablet/desktop.
    return StatsRow(stats: stats, responsive: responsive);
  }

  Widget _buildSearchAndFilter(dynamic responsive, AdvisoryProvider provider) {
    return Container(
      padding: EdgeInsets.all(responsive.scale(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar on top
          Search(
            controller: _searchController,
            debounceDuration: const Duration(milliseconds: 300),
            hint: 'Search by address...',
            onSearch: (q) => provider.searchAdvisories(q),
            onClear: () => provider.searchAdvisories(''),
          ),
          SizedBox(height: responsive.scale(12)),
          // Row: Filter label (left) and barangay selector badge/button (right)
          Row(
            children: [
              // Left-aligned label
              Text(
                'Filter',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: responsive.scaleFont(16),
                ),
              ),
              const Spacer(),

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
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.scale(12),
                            vertical: responsive.scale(8),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: responsive.scale(14),
                                color: Colors.grey[700],
                              ),
                              SizedBox(width: responsive.scale(8)),
                              Text(
                                adminBarangay,
                                style: TextStyle(
                                  fontSize: responsive.scaleFont(13),
                                  color: Colors.grey[800],
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
                          List<AdvisoryStatus>? statuses =
                              provider.currentStatuses;
                          if (statuses == null && userRole == UserRole.user) {
                            statuses = [
                              AdvisoryStatus.active,
                              AdvisoryStatus.scheduled,
                            ];
                          }
                          await provider.startAdvisoryStream(
                            barangay: b?.name,
                            useRealtime: true,
                            initialFilter: provider.currentFilter,
                            statuses: statuses,
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
                      onPressed: () =>
                          provider.applyFilter(AdvisoryViewFilter.all),
                    ),
                    SizedBox(width: responsive.scale(8)),
                    FilterChipButton(
                      responsive: responsive,
                      label: 'Active',
                      icon: Icons.play_circle_filled,
                      selected:
                          provider.currentFilter == AdvisoryViewFilter.active,
                      color: Colors.green,
                      onPressed: () =>
                          provider.applyFilter(AdvisoryViewFilter.active),
                    ),
                    SizedBox(width: responsive.scale(8)),
                    FilterChipButton(
                      responsive: responsive,
                      label: 'Scheduled',
                      icon: Icons.schedule,
                      selected:
                          provider.currentFilter ==
                          AdvisoryViewFilter.scheduled,
                      color: Colors.orange,
                      onPressed: () =>
                          provider.applyFilter(AdvisoryViewFilter.scheduled),
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
                        color: Colors.red,
                        onPressed: () =>
                            provider.applyFilter(AdvisoryViewFilter.inactive),
                      ),
                      SizedBox(width: responsive.scale(8)),
                      FilterChipButton(
                        responsive: responsive,
                        label: 'Expired',
                        icon: Icons.history,
                        selected:
                            provider.currentFilter ==
                            AdvisoryViewFilter.expired,
                        color: Colors.grey,
                        onPressed: () =>
                            provider.applyFilter(AdvisoryViewFilter.expired),
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

  Widget _buildStatsBar(dynamic responsive, AdvisoryProvider provider) {
    // Show count of persisted-active advisories within filtered set
    final active = provider.filteredAdvisories
        .where((a) => a.status == AdvisoryStatus.active)
        .length;
    final total = provider.filteredAdvisories.length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scale(16),
        vertical: responsive.scale(8),
      ),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: responsive.scale(18)),
          SizedBox(width: responsive.scale(8)),
          Text(
            '$active active of $total advisories',
            style: TextStyle(
              fontSize: responsive.scaleFont(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryCards(dynamic responsive, AdvisoryProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            SizedBox(height: responsive.scale(16)),
            Text(
              'Error loading advisories',
              style: TextStyle(fontSize: responsive.scaleFont(16)),
            ),
            SizedBox(height: responsive.scale(8)),
            Text(
              provider.error!,
              style: TextStyle(
                fontSize: responsive.scaleFont(12),
                color: Colors.grey,
              ),
            ),
            SizedBox(height: responsive.scale(16)),
            ElevatedButton.icon(
              onPressed: _loadAdvisories,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.filteredAdvisories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: responsive.scale(16)),
            Text(
              'No advisories found',
              style: TextStyle(
                fontSize: responsive.scaleFont(16),
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(responsive.scale(16)),
      itemCount: provider.filteredAdvisories.length,
      separatorBuilder: (_, __) => SizedBox(height: responsive.scale(12)),
      itemBuilder: (context, index) {
        final advisory = provider.filteredAdvisories[index];
        return _buildAdvisoryCard(responsive, advisory);
      },
    );
  }

  Widget _buildAdvisoryCard(dynamic responsive, Advisory advisory) {
    final category = AdvisoryCategory.findById(advisory.advisoryType);
    // Use persisted status only (no runtime computation)
    final status = advisory.status;
    // read-only to avoid rebuilding every card when UserProvider changes
    final userProvider = context.read<UserProvider>();
    final canEdit = userProvider.isAdmin || userProvider.isSysAdmin;

    // Color-code card by advisory status for clear visual affordance.
    // Keep mapping local and cheap to compute for performance.
    Color statusColorFor(AdvisoryStatus s) {
      switch (s) {
        case AdvisoryStatus.active:
          return Colors.green;
        case AdvisoryStatus.scheduled:
          return Colors.orange;
        case AdvisoryStatus.inactive:
          return Colors.red; // changed: inactive -> red
        case AdvisoryStatus.expired:
          return Colors.grey; // changed: expired -> grey
      }
    }

    final statusColor = statusColorFor(status);

    // Subtle accent used for border / header background
    final borderColor = statusColor.withValues(alpha: 0.55);
    final headerBg = statusColor.withValues(alpha: 0.08);

    // Precompute formatted strings to avoid repeated formatter instantiation.
    final String startFriendly = DateFormatUtils.formatFriendly(
      advisory.startDate,
    );
    final String endFriendly = DateFormatUtils.formatFriendly(advisory.endDate);
    final String updatedFriendly = DateFormatUtils.formatFriendly(
      advisory.updatedAt,
    );

    // Increase card sizes slightly on mobile only (keeps desktop/tablet unchanged)
    final bool isMobile = (responsive?.isMobile ?? false);
    final double mobileBoost = isMobile ? 1.12 : 1.0;
    double s(double v) => responsive.scale(v) * mobileBoost;
    double sf(double v) => responsive.scaleFont(v) * (isMobile ? 1.06 : 1.0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // Use status-based border color for clearer signal (category color still used in header icon)
          color: borderColor,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _showAdvisoryDetails(advisory),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(s(12)),
              decoration: BoxDecoration(
                // Blend category icon color with status background for consistent branding
                color: headerBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (category != null)
                    Container(
                      width: s(48),
                      height: s(48),
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconForCategory(category.id),
                        color: Colors.white,
                        size: s(26),
                      ),
                    ),
                  SizedBox(width: s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category?.title ?? advisory.advisoryType,
                          style: TextStyle(
                            fontSize: sf(17),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: s(6) * (isMobile ? 1 : 0.7)),

                        // Barangay badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: s(8),
                            vertical: s(4),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: s(14),
                                color: Colors.grey.shade700,
                              ),
                              SizedBox(width: s(6)),
                              Text(
                                advisory.barangay,
                                style: TextStyle(
                                  fontSize: sf(12),
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Place name chip (if available)
                        if (advisory.placeName != null &&
                            advisory.placeName!.isNotEmpty) ...[
                          SizedBox(height: s(6)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: s(8),
                              vertical: s(4),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.place,
                                  size: s(14),
                                  color: Colors.blue.shade700,
                                ),
                                SizedBox(width: s(6)),
                                Flexible(
                                  child: Text(
                                    advisory.placeName!,
                                    style: TextStyle(
                                      fontSize: sf(12),
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusBadge(responsive, status),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(s(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    advisory.reason,
                    style: TextStyle(fontSize: sf(15)),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: s(12)),

                  // Date range for one-time advisories. Recurring advisories show
                  // their schedule below instead, so hide the date range.
                  if (advisory.scheduleType == AdvisoryScheduleType.oneTime)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: s(16),
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: s(6)),
                        Expanded(
                          child: Text(
                            '$startFriendly — $endFriendly',
                            style: TextStyle(
                              fontSize: sf(13),
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Schedule Info
                  if (advisory.scheduleType ==
                      AdvisoryScheduleType.recurring) ...[
                    SizedBox(height: s(6)),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          size: s(16),
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: s(6)),
                        Flexible(
                          child: Text(
                            _formatSchedule(advisory),
                            style: TextStyle(
                              fontSize: sf(13),
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Meta: Updated timestamp (formatted via utils)
                  SizedBox(height: s(8)),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: s(14),
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: s(6)),
                      Expanded(
                        child: Text(
                          'Updated $updatedFriendly',
                          style: TextStyle(
                            fontSize: sf(12),
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Contractor Info (if applicable)
                  if (advisory.contractor != null) ...[
                    SizedBox(height: s(8)),
                    Container(
                      padding: EdgeInsets.all(s(8)),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: s(16),
                            color: Colors.orange,
                          ),
                          SizedBox(width: s(8)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  advisory.contractor!,
                                  style: TextStyle(
                                    fontSize: sf(13),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (advisory.contractorContact != null)
                                  Text(
                                    advisory.contractorContact!,
                                    style: TextStyle(
                                      fontSize: sf(12),
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            if (canEdit)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: s(8)),
                child: SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      // Delete at the very left
                      TextButton.icon(
                        onPressed: () => _deleteAdvisory(advisory),
                        icon: Icon(
                          Icons.delete,
                          size: s(18),
                          color: Colors.red,
                        ),
                        label: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red, fontSize: sf(13)),
                        ),
                      ),

                      // Center: Download button (expands center space, keeps button centered)
                      Expanded(
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => _downloadAdvisory(advisory),
                            icon: Icon(Icons.download, size: s(18)),
                            label: Text(
                              'Download',
                              style: TextStyle(fontSize: sf(13)),
                            ),
                          ),
                        ),
                      ),

                      // Edit at the very right
                      TextButton.icon(
                        onPressed: () => _navigateToEdit(context, advisory),
                        icon: Icon(Icons.edit, size: s(18)),
                        label: Text('Edit', style: TextStyle(fontSize: sf(13))),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(dynamic responsive, AdvisoryStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case AdvisoryStatus.active:
        // persisted-active -> show Active (server is authoritative)
        color = Colors.green;
        icon = Icons.play_circle_filled;
        label = 'Active';
        break;
      case AdvisoryStatus.scheduled:
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'Scheduled';
        break;
      case AdvisoryStatus.expired:
        color = Colors.grey; // expired -> grey
        icon = Icons.history;
        label = 'Expired';
        break;
      case AdvisoryStatus.inactive:
        color = Colors.red; // inactive -> red
        icon = Icons.pause;
        label = 'Inactive';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.scale(8),
        vertical: responsive.scale(4),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: responsive.scale(14), color: color),
          SizedBox(width: responsive.scale(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: responsive.scaleFont(11),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSchedule(Advisory advisory) {
    if (advisory.weekdays == null || advisory.weekdays!.isEmpty) return '';

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDays = advisory.weekdays!.map((d) => days[d - 1]).join(', ');

    if (advisory.recurringStartTime != null &&
        advisory.recurringEndTime != null) {
      return '$selectedDays (${advisory.recurringStartTime!.format(context)} - ${advisory.recurringEndTime!.format(context)})';
    }

    return selectedDays;
  }

  IconData _getIconForCategory(String categoryId) {
    switch (categoryId) {
      case 'road_closure':
        return Icons.block;
      case 'stop_and_go':
        return Icons.traffic;
      case 'one_way':
        return Icons.arrow_forward;
      case 'construction':
        return Icons.construction;
      case 'partial_lane':
        return Icons.remove_road;
      case 'event':
        return Icons.event;
      case 'emergency':
        return Icons.warning;
      default:
        return Icons.info;
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
