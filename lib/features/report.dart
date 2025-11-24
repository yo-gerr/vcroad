import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/report.dart';
import 'package:vcroad_v2/shared/providers/report.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/dialog/report.dart';
import 'package:vcroad_v2/shared/widgets/report/history.dart';
import 'package:vcroad_v2/shared/utils/stats/stats.dart';
import 'package:vcroad_v2/shared/utils/search/filter.dart';
import 'package:vcroad_v2/shared/utils/search/search.dart';
import 'package:vcroad_v2/shared/utils/search/barangay_filter.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/widgets/report/report_steps.dart';

class Report extends StatefulWidget {
  const Report({super.key});

  @override
  State<Report> createState() => _ReportState();
}

class _ReportState extends State<Report> {
  // Filter state
  ReportCategory? _filterCategory;
  ReportStatus? _filterStatus;
  Barangay? _selectedBarangay;
  // single BarangayService instance reused by the BarangayFilter (matches Advisory UX)
  final BarangayService _barangayService = BarangayService();

  String _searchQuery = ''; // search text
  bool _applyingFilters = false;

  // Reports are delivered via streams in ReportProvider; no manual refresh needed.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters(); // start with current (empty) filters so provider query is server-side
      final user = context.read<UserProvider>().user;
      if (user != null) {
        // keep initial myReports minimal; history will request full list when opened
        context.read<ReportProvider>().listenMyReports(user.userId);
      }
    });
  }

  void _openHistory() {
    final user = context.read<UserProvider>().user;
    if (user != null) {
      // Ensure history shows all user's reports regardless of status
      context.read<ReportProvider>().listenMyReports(
        user.userId,
        activeOnly: false,
      );
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: ReportHistorySheet(),
      ),
    );
  }

  void _applyFilters() {
    if (_applyingFilters) return;
    _applyingFilters = true;
    Future<void>.delayed(const Duration(milliseconds: 120)).then((_) {
      if (!mounted) return;
      final userProv = context.read<UserProvider>();
      String? barangayParam;
      if (userProv.isAdmin && !userProv.isSysAdmin) {
        barangayParam = userProv.user?.barangay.name;
      } else {
        barangayParam = _selectedBarangay?.name;
      }

      // For regular users exclude resolved & flagged results server-side
      final excludeForRegularUser = userProv.isUser;

      context.read<ReportProvider>().listenAllReports(
        category: _filterCategory,
        status: _filterStatus,
        barangay: barangayParam,
        limit: 100,
        excludeResolvedAndFlagged: excludeForRegularUser,
      );
      _applyingFilters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    // role-aware title: sysadmin > admin > regular user
    final userProv = context.watch<UserProvider?>();
    final titleText = (userProv != null && userProv.isSysAdmin)
        ? 'System Report Management'
        : (userProv != null && userProv.isAdmin)
        ? 'Report Management'
        : 'Reports';

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
        actions: [
          // Hide the history button for admin / sysadmin users (inaccessible).
          if (!(userProv?.isAdmin == true || userProv?.isSysAdmin == true))
            IconButton(
              tooltip: 'My Reports',
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: _openHistory,
            ),
        ],
      ),
      // Center content and constrain max width like Advisory.
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: responsive.isDesktop ? 1100 : responsive.maxFormWidth,
          ),
          child: SafeArea(child: _buildReportList(responsive)),
        ),
      ),

      // FAB to open the report steps — shown only to users allowed to report.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Builder(
        builder: (ctx) {
          final canReport = ctx.watch<UserProvider>().canReport;
          if (!canReport) return const SizedBox.shrink();

          final info = ctx.responsive;
          const tooltip = 'Report Traffic Issue';

          if (info.isMobile) {
            return FloatingActionButton(
              heroTag: 'fab_report_steps',
              onPressed: () {
                Navigator.of(ctx).push(
                  MaterialPageRoute(builder: (_) => const ReportStepsScreen()),
                );
              },
              tooltip: tooltip,
              backgroundColor: const Color(0xFF001278),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          }

          return FloatingActionButton.extended(
            heroTag: 'fab_report_steps',
            onPressed: () {
              Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const ReportStepsScreen()),
              );
            },
            backgroundColor: const Color(0xFF001278),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(
              'Report Issue',
              style: TextStyle(fontSize: info.scaleFont(14)),
            ),
            tooltip: tooltip,
          );
        },
      ),
    );
  }

  Widget _buildReportList(dynamic responsive) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final all = provider.allReports;
        // Only compute and show stats for admin/sysadmin users to avoid unnecessary work.
        final userProv = context.watch<UserProvider>();
        final showStats = userProv.isAdmin || userProv.isSysAdmin;

        int total = 0;
        List<StatsUtils> stats = const [];
        if (showStats) {
          total = all.length;
          final pending = all
              .where(
                (r) =>
                    ((r as dynamic).statusLabel ?? '').toLowerCase() ==
                    'pending',
              )
              .length;
          final verified = all
              .where(
                (r) =>
                    ((r as dynamic).statusLabel ?? '').toLowerCase() ==
                    'verified',
              )
              .length;
          final resolved = all
              .where(
                (r) =>
                    ((r as dynamic).statusLabel ?? '').toLowerCase() ==
                    'resolved',
              )
              .length;
          final flagged = all
              .where(
                (r) =>
                    ((r as dynamic).statusLabel ?? '').toLowerCase() ==
                    'flagged',
              )
              .length;

          stats = [
            StatsUtils(
              label: 'Total',
              value: total.toString(),
              icon: Icons.list,
              color: const Color(0xFF001278),
            ),
            StatsUtils(
              label: 'Pending',
              value: pending.toString(),
              icon: Icons.pause,
              color: Colors.grey,
            ),
            StatsUtils(
              label: 'Verified',
              value: verified.toString(),
              icon: Icons.verified,
              color: Colors.green,
            ),
            StatsUtils(
              label: 'Resolved',
              value: resolved.toString(),
              icon: Icons.check_circle,
              color: Colors.blue,
            ),
            StatsUtils(
              label: 'Flagged',
              value: flagged.toString(),
              icon: Icons.flag,
              color: Colors.red,
            ),
          ];
        } else {
          total = all.length;
        }

        // Search + filter area
        final searchAndFilter = Container(
          padding: EdgeInsets.all(responsive.scale(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Search(
                hint: 'Search by address...',
                debounceDuration: const Duration(milliseconds: 300),
                onSearch: (q) {
                  if (!mounted) return;
                  setState(() => _searchQuery = q.trim());
                },
                onClear: () {
                  if (!mounted) return;
                  setState(() => _searchQuery = '');
                },
              ),
              SizedBox(height: responsive.scale(12)),
              Row(
                children: [
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: responsive.scaleFont(16),
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: responsive.scale(8),
                    runSpacing: responsive.scale(8),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Barangay filter
                      Builder(
                        builder: (ctx) {
                          final up = ctx.watch<UserProvider>();
                          final isAdminOnly = up.isAdmin && !up.isSysAdmin;
                          if (isAdminOnly) {
                            final adminBarangay =
                                up.user?.barangay.name ?? 'N/A';
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
                                mainAxisSize: MainAxisSize.min,
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

                          return BarangayFilter(
                            selected: _selectedBarangay,
                            barangayService: _barangayService,
                            selectLabel: 'Select Barangay',
                            showClear: true,
                            onChanged: (b) async {
                              setState(() => _selectedBarangay = b);
                              _applyFilters();
                            },
                          );
                        },
                      ),
                      // Category filter button
                      _buildCategoryFilterButton(responsive),
                    ],
                  ),
                ],
              ),
              SizedBox(height: responsive.scale(12)),
              // Status chips row only
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // All
                          FilterChipButton(
                            responsive: responsive,
                            label: 'All',
                            icon: Icons.list,
                            selected: _filterStatus == null,
                            color: Colors.grey.shade800,
                            onPressed: () {
                              setState(() => _filterStatus = null);
                              _applyFilters();
                            },
                          ),
                          SizedBox(width: responsive.scale(8)),

                          // Pending
                          FilterChipButton(
                            responsive: responsive,
                            label: 'Pending',
                            icon: Icons.pause,
                            selected: _filterStatus == ReportStatus.pending,
                            color: ReportStatus.pending.color,
                            onPressed: () {
                              setState(
                                () => _filterStatus =
                                    _filterStatus == ReportStatus.pending
                                    ? null
                                    : ReportStatus.pending,
                              );
                              _applyFilters();
                            },
                          ),
                          SizedBox(width: responsive.scale(8)),

                          // Verified
                          FilterChipButton(
                            responsive: responsive,
                            label: 'Verified',
                            icon: Icons.verified,
                            selected: _filterStatus == ReportStatus.verified,
                            color: ReportStatus.verified.color,
                            onPressed: () {
                              setState(
                                () => _filterStatus =
                                    _filterStatus == ReportStatus.verified
                                    ? null
                                    : ReportStatus.verified,
                              );
                              _applyFilters();
                            },
                          ),
                          SizedBox(width: responsive.scale(8)),

                          // Resolved: show only to admins/sysadmin
                          if (!context.read<UserProvider>().isUser)
                            FilterChipButton(
                              responsive: responsive,
                              label: 'Resolved',
                              icon: Icons.check_circle,
                              selected: _filterStatus == ReportStatus.resolved,
                              color: ReportStatus.resolved.color,
                              onPressed: () {
                                setState(
                                  () => _filterStatus =
                                      _filterStatus == ReportStatus.resolved
                                      ? null
                                      : ReportStatus.resolved,
                                );
                                _applyFilters();
                              },
                            ),
                          SizedBox(width: responsive.scale(8)),

                          // Flagged: show only to admins/sysadmin
                          if (!context.read<UserProvider>().isUser)
                            FilterChipButton(
                              responsive: responsive,
                              label: 'Flagged',
                              icon: Icons.flag,
                              selected: _filterStatus == ReportStatus.flagged,
                              color: ReportStatus.flagged.color,
                              onPressed: () {
                                setState(
                                  () => _filterStatus =
                                      _filterStatus == ReportStatus.flagged
                                      ? null
                                      : ReportStatus.flagged,
                                );
                                _applyFilters();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        Widget statsBar = Container(
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
                '$total reports',
                style: TextStyle(
                  fontSize: responsive.scaleFont(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

        return Column(
          children: [
            if (showStats)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.scale(16),
                  vertical: responsive.scale(16),
                ),
                child: StatsRow(stats: stats, responsive: responsive),
              ),
            searchAndFilter,
            const Divider(height: 1),
            if (showStats && all.isNotEmpty) statsBar,
            Expanded(child: _buildReportCards(responsive)),
          ],
        );
      },
    );
  }

  // Builds the actual cards list with same padding/responsiveness as Advisory.
  Widget _buildReportCards(dynamic responsive) {
    // Use provider state for loading/error if you add those; currently stream-driven.
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        final info = responsive;
        final reports = provider.allReports;
        final query = _searchQuery.trim().toLowerCase();
        var filtered = query.isEmpty
            ? reports
            : reports
                  .where(
                    (r) =>
                        ((r.address)).toString().toLowerCase().contains(query),
                  )
                  .toList();

        // Additional enforcement: if current user is admin (not sysadmin), ensure
        // only reports from the admin's barangay are shown (defensive client-side filter).
        final up = context.watch<UserProvider>();
        final isAdminOnly = up.isAdmin && !up.isSysAdmin;
        final adminBarangay = up.user?.barangay.name;
        if (isAdminOnly) {
          filtered = filtered
              .where((r) => (r.barangay).toString() == (adminBarangay ?? ''))
              .toList();
        }

        // Regular users must NOT see resolved or flagged reports (defensive client-side filter)
        if (up.isUser) {
          filtered = filtered
              .where((r) => !(r.isResolved || r.isFlagged))
              .toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.report,
                  size: info.scale(64),
                  color: Colors.grey[400],
                ),
                SizedBox(height: info.scale(12)),
                Text(
                  query.isEmpty
                      ? 'No reports yet'
                      : 'No results for "$_searchQuery"',
                  style: TextStyle(
                    fontSize: info.scaleFont(18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: info.scale(8)),
                Text(
                  query.isEmpty
                      ? 'Use the button to create a traffic issue report.'
                      : 'Try a different address or clear the search.',
                  style: TextStyle(
                    fontSize: info.scaleFont(14),
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(responsive.scale(16)),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => SizedBox(height: responsive.scale(12)),
          itemBuilder: (context, index) {
            final r = filtered[index];
            return _ReportListItem(report: r);
          },
        );
      },
    );
  }

  /// Category filter button styled like BarangayFilter
  Widget _buildCategoryFilterButton(dynamic responsive) {
    return OutlinedButton.icon(
      onPressed: () => _openCategorySelector(responsive),
      icon: Icon(Icons.category, size: responsive.scale(14)),
      label: Text(
        _filterCategory?.label ?? 'Select Category',
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.scale(12),
          vertical: responsive.scale(8),
        ),
        side: BorderSide(color: Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Opens category selector dialog/bottom sheet
  Future<void> _openCategorySelector(dynamic responsive) async {
    ReportCategory? result;
    List<ReportCategory> categories = ReportCategory.values;

    Widget content(StateSetter setState) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Category',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = categories[i];
                // larger, responsive icon sizing for better touch/visibility
                final double iconBoxSize = responsive.scale(
                  44,
                ); // container size
                final double iconInnerPadding = responsive.scale(
                  8,
                ); // padding inside box
                final double fallbackIconSize = responsive.scale(
                  20,
                ); // fallback icon
                return ListTile(
                  title: Text(c.label),
                  leading: Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: c.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // Use the category asset defined on the model. Fallback to
                    // a simple icon if the asset fails to load.
                    child: Padding(
                      padding: EdgeInsets.all(iconInnerPadding),
                      child: Image.asset(
                        c.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.category,
                          size: fallbackIconSize,
                          color: c.color,
                        ),
                      ),
                    ),
                  ),
                  selected: _filterCategory == c,
                  onTap: () => Navigator.of(context).pop(c),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear selection'),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (responsive.isMobile) {
      result = await showModalBottomSheet<ReportCategory?>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        builder: (_) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: StatefulBuilder(builder: (_, s) => content(s)),
          ),
        ),
      );
    } else {
      result = await showDialog<ReportCategory?>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 500),
            child: StatefulBuilder(builder: (_, s) => content(s)),
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() => _filterCategory = result);
    _applyFilters();
  }
}

class _ReportListItem extends StatelessWidget {
  final ReportData report;
  const _ReportListItem({required this.report});

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final bool isMobile = responsive.isMobile;
    double s(double v) => responsive.scale(v) * (isMobile ? 1.03 : 1.0);
    double sf(double v) => responsive.scaleFont(v) * (isMobile ? 1.02 : 1.0);

    final user = context.watch<UserProvider>().user;
    final userProv = context.watch<UserProvider>();
    final userId = user?.userId;
    // only regular users may interact
    final canInteract =
        userId != null && report.canUserInteract(userId) && userProv.isUser;
    final confirmed = userId != null && report.hasUserConfirmed(userId);
    final refuted = userId != null && report.hasUserRefuted(userId);

    final categoryColor = report.category.color;

    // Status color mapping: pending grey, verified green, resolved blue, flagged red.
    final ReportStatus status = report.status;
    final Color statusColor = (() {
      switch (status) {
        case ReportStatus.verified:
          return Colors.green.shade600;
        case ReportStatus.resolved:
          return Colors.blue.shade600;
        case ReportStatus.flagged:
          return Colors.red.shade600;
        case ReportStatus.pending:
          return Colors.grey.shade600;
      }
    })();

    // Address extracted once before the widget tree to allow collection-if usage below.
    final addr = (report as dynamic).address;
    final hasAddress = addr != null && addr.toString().trim().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.18), width: 2),
      ),
      child: InkWell(
        onTap: () => _showReportDetails(context, report.reportId),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(s(12)),
              decoration: BoxDecoration(
                // color the header using a subtle tint from the status color
                color: statusColor.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon / asset
                  Container(
                    width: s(44),
                    height: s(44),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(s(6)),
                      child: Image.asset(
                        report.category.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.location_on, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(width: s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.category.label,
                          style: TextStyle(
                            fontSize: sf(16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: s(6)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    size: s(12),
                                    color: Colors.grey[700],
                                  ),
                                  SizedBox(width: s(6)),
                                  Text(
                                    report.barangay,
                                    style: TextStyle(
                                      fontSize: sf(11),
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: s(8)),
                            // time ago
                            Text(
                              report.timeAgo,
                              style: TextStyle(
                                fontSize: sf(12),
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        // Address (below barangay) — styled badge (blue)
                        if (hasAddress)
                          Padding(
                            padding: EdgeInsets.only(top: s(6)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: s(8),
                                vertical: s(6),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue.shade100,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: s(12),
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: s(6)),
                                  Flexible(
                                    child: Text(
                                      addr,
                                      style: TextStyle(
                                        fontSize: sf(12),
                                        color: Colors.blue.shade700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ensure badge uses same mapping/colors
                  _buildStatusBadge(responsive, report.status),
                ],
              ),
            ),

            // Body / excerpt (counts)
            Padding(
              padding: EdgeInsets.all(s(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.thumb_up, size: s(16), color: Colors.green),
                      SizedBox(width: s(6)),
                      Text('${report.confirmCount}'),
                      SizedBox(width: s(12)),
                      Icon(Icons.thumb_down, size: s(16), color: Colors.red),
                      SizedBox(width: s(6)),
                      Text('${report.refuteCount}'),
                    ],
                  ),
                ],
              ),
            ),

            // Interaction buttons (only when user can interact)
            if (canInteract)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: s(12),
                ).copyWith(bottom: s(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          Icons.thumb_up,
                          size: s(18),
                          color: confirmed ? Colors.green : null,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Confirm (${report.confirmCount})',
                              style: TextStyle(
                                fontSize: sf(12),
                                color: confirmed ? Colors.green.shade700 : null,
                                fontWeight: confirmed ? FontWeight.w700 : null,
                              ),
                            ),
                            SizedBox(width: s(6)),
                            // small check badge that fades in when selected
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              opacity: confirmed ? 1.0 : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: confirmed
                                      ? Colors.green
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                padding: EdgeInsets.all(s(2)),
                                child: Icon(
                                  Icons.check,
                                  size: s(12),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: confirmed
                              ? Colors.green.withValues(alpha: 0.08)
                              : null,
                          side: BorderSide(
                            color: confirmed
                                ? Colors.green.shade700
                                : Colors.grey.shade300,
                          ),
                          padding: EdgeInsets.symmetric(vertical: s(10)),
                        ),
                        onPressed: () => context.read<ReportProvider>().confirm(
                          report,
                          userId,
                        ),
                      ),
                    ),
                    SizedBox(width: s(8)),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          Icons.thumb_down,
                          size: s(18),
                          color: refuted ? Colors.red : null,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Refute (${report.refuteCount})',
                              style: TextStyle(
                                fontSize: sf(12),
                                color: refuted ? Colors.red.shade700 : null,
                                fontWeight: refuted ? FontWeight.w700 : null,
                              ),
                            ),
                            SizedBox(width: s(6)),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 220),
                              opacity: refuted ? 1.0 : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: refuted
                                      ? Colors.red
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                padding: EdgeInsets.all(s(2)),
                                child: Icon(
                                  Icons.check,
                                  size: s(12),
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: refuted
                              ? Colors.red.withValues(alpha: 0.08)
                              : null,
                          side: BorderSide(
                            color: refuted
                                ? Colors.red.shade700
                                : Colors.grey.shade300,
                          ),
                          padding: EdgeInsets.symmetric(vertical: s(10)),
                        ),
                        onPressed: () => context.read<ReportProvider>().refute(
                          report,
                          userId,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Small helpers copied/adapted from advisory UI for consistency.

Widget _buildStatusBadge(dynamic responsive, ReportStatus status) {
  final color = status.color;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: (responsive?.scale ?? (double x) => x)(8),
      vertical: (responsive?.scale ?? (double x) => x)(4),
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.label,
          size: (responsive?.scale ?? (double x) => x)(14),
          color: color,
        ),
        SizedBox(width: (responsive?.scale ?? (double x) => x)(4)),
        Text(
          status.label,
          style: TextStyle(
            fontSize: (responsive?.scaleFont ?? (double x) => x)(11),
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

void _showReportDetails(BuildContext context, String reportId) {
  ReportDetailsDialog.show(context, reportId);
}
