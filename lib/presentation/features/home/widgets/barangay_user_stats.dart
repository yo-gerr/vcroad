import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/stats.dart';
import 'package:vcroad/data/repositories/account.dart';
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/data/repositories/google_sheets.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vcroad/core/utils/format/date_time.dart';
import 'package:vcroad/presentation/features/home/widgets/stats_common.dart';

class BarangayUserStats extends StatefulWidget {
  final List<BarangayUserStat> stats;
  // optional timestamp for footer; if null current time will be used
  final DateTime? timestamp;
  // Optional loader for pull-to-refresh. Defaults to the shared, cached
  // AccountService aggregation with a forced refresh.
  final Future<List<BarangayUserStat>> Function()? onRefresh;

  const BarangayUserStats({
    super.key,
    required this.stats,
    this.timestamp,
    this.onRefresh,
  });

  @override
  State<BarangayUserStats> createState() => _BarangayUserStatsState();
}

class _BarangayUserStatsState extends State<BarangayUserStats> {
  late List<BarangayUserStat> _original;
  late List<BarangayUserStat> _filtered;
  String _query = '';
  bool _exporting = false;
  bool _refreshing = false;
  bool _error = false;
  int _originalTotal = 0;
  late DateTime _asOf;

  @override
  void initState() {
    super.initState();
    _original = List<BarangayUserStat>.from(widget.stats);
    _filtered = _original;
    _asOf = widget.timestamp ?? DateTime.now();
    _computeOriginalTotals();
    const returnAsset = 'assets/icons/return.webp';
    try {
      precacheImage(const AssetImage(returnAsset), context);
    } catch (_) {}

    final svc = BarangayService();
    if (!svc.isLoaded && !svc.isLoading) {
      svc
          .loadBarangays()
          .then((_) {
            try {
              if (!mounted) return;
              svc.preloadLogos(context, max: 40);
            } catch (_) {}
            if (mounted) setState(() {});
          })
          .catchError((e) {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _computeOriginalTotals() {
    final agg = _original.fold<List<int>>(
      [0, 0, 0],
      (acc, s) => [
        acc[0] + s.total,
        acc[1] + s.verified,
        acc[2] + s.unverified,
      ],
    );
    _originalTotal = agg[0];
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filtered = _original;
    } else {
      _filtered = _original
          .where((s) => s.barangay.toLowerCase().contains(_query))
          .toList();
    }
  }

  void _onSearchChanged(String q) {
    setState(() {
      _query = q.trim().toLowerCase();
      _applyFilter();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final loader =
        widget.onRefresh ??
        () => AccountService.instance.getUserStatsPerBarangay(
          includeZeroEntries: true,
          forceRefresh: true,
        );

    setState(() {
      _refreshing = true;
      _error = false;
    });
    try {
      final stats = await loader();
      if (!mounted) return;
      setState(() {
        _original = List<BarangayUserStat>.from(stats);
        _computeOriginalTotals();
        _applyFilter();
        _asOf = DateTime.now();
        _refreshing = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      if (kDebugMode) {
        debugPrint('Failed to refresh per-barangay stats: $e\n$st');
      }
      if (_original.isEmpty) {
        setState(() {
          _error = true;
          _refreshing = false;
        });
      } else {
        setState(() => _refreshing = false);
        SnackbarUtils.show(
          context,
          'Failed to refresh stats. Showing last loaded data.',
          icon: Icons.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final colorScheme = Theme.of(context).colorScheme;

    final sorted = List<BarangayUserStat>.from(_filtered)
      ..sort((a, b) => b.total.compareTo(a.total));
    // show only barangays that have at least one user (hide zero rows)
    final visible = sorted.where((s) => s.total > 0).toList();

    // Totals/summary based on visible rows
    final displayedTotal = visible.fold<int>(0, (acc, s) => acc + s.total);
    final displayedVerified = visible.fold<int>(
      0,
      (acc, s) => acc + s.verified,
    );
    final displayedUnverified = visible.fold<int>(
      0,
      (acc, s) => acc + s.unverified,
    );

    final maxTotal = visible.isNotEmpty
        ? visible.map((s) => s.total).fold<int>(0, (a, b) => a > b ? a : b)
        : 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            padding: EdgeInsets.all(info.scale(8)),
            iconSize: info.scale(32),
            icon: Image.asset(
              'assets/icons/return.webp',
              width: info.scale(24),
              height: info.scale(24),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: info.scale(24),
              ),
            ),
          ),
        ),
        title: Text(
          'Users per Barangay',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: _refreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshing ? null : _refresh,
          ),
          PopupMenuButton<String>(
            tooltip: 'Export',
            enabled: !_exporting && !_refreshing,
            onSelected: (value) {
              if (value == 'all') {
                _confirmAndExportAll();
              } else if (value == 'filtered') {
                _confirmAndExportFiltered();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Export all barangays'),
              ),
              if (_query.isNotEmpty)
                PopupMenuItem(
                  value: 'filtered',
                  child: Text('Export filtered (${_filtered.length})'),
                ),
            ],
            child: Padding(
              padding: EdgeInsets.all(info.scale(8)),
              child: _exporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(info.scale(16)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: StatsSearchField(onChanged: _onSearchChanged)),
                SizedBox(width: info.scale(12)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Showing ${visible.length}',
                      style: TextStyle(fontSize: info.scaleFont(12)),
                    ),
                    if (_query.isNotEmpty)
                      Text(
                        'Filter: "$_query"',
                        style: TextStyle(
                          fontSize: info.scaleFont(11),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: info.scale(12)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(info.scale(12)),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total users',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: info.scale(6)),
                      Text(
                        '$displayedTotal',
                        style: TextStyle(
                          fontSize: info.scaleFont(18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (displayedTotal != _originalTotal)
                        Text(
                          'of $_originalTotal total',
                          style: TextStyle(
                            fontSize: info.scaleFont(11),
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: info.scale(6)),
                      Text(
                        '$displayedVerified',
                        style: TextStyle(
                          fontSize: info.scaleFont(16),
                          color: kVerifiedColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Unverified',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: info.scale(6)),
                      Text(
                        '$displayedUnverified',
                        style: TextStyle(
                          fontSize: info.scaleFont(16),
                          color: kUnverifiedColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: info.scale(8)),
                  Column(
                    children: [
                      Text(
                        'Verified %',
                        style: TextStyle(
                          fontSize: info.scaleFont(11),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: info.scale(6)),
                      Text(
                        displayedTotal > 0
                            ? '${((displayedVerified / displayedTotal) * 100).toStringAsFixed(1)}%'
                            : '—',
                        style: TextStyle(
                          fontSize: info.scaleFont(14),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: info.scale(12)),
            StatsLegend(
              items: const [
                ('Verified', kVerifiedColor),
                ('Unverified', kUnverifiedColor),
              ],
            ),
            SizedBox(height: info.scale(12)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: _error
                    ? _buildErrorState(context, info)
                    : visible.isEmpty
                    ? _buildEmptyState(context, info)
                    : context.isDesktop
                    ? GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: info.scale(6)),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 380,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 4.2,
                            ),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final s = visible[index];
                          return _RowStat(
                            stat: s,
                            maxTotal: maxTotal,
                            info: info,
                          );
                        },
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: info.scale(6)),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final s = visible[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: info.scale(6),
                            ),
                            child: _RowStat(
                              stat: s,
                              maxTotal: maxTotal,
                              info: info,
                            ),
                          );
                        },
                      ),
              ),
            ),
            SizedBox(height: info.scale(12)),
            Text(
              'as of ${DateFormatUtils.formatFriendly(_asOf)}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: info.scaleFont(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ResponsiveInfo info) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: info.scale(80)),
        Icon(
          Icons.groups_outlined,
          size: info.scale(48),
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No user data yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: info.scaleFont(14)),
        ),
        const SizedBox(height: 4),
        Text(
          'Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: info.scaleFont(12),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, ResponsiveInfo info) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: info.scale(80)),
        Icon(
          Icons.error_outline,
          size: info.scale(48),
          color: colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(
          'Failed to load stats',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: info.scaleFont(14)),
        ),
        const SizedBox(height: 4),
        Text(
          'Pull down to retry.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: info.scaleFont(12),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: info.scale(16)),
        Center(
          child: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndExportAll() async {
    final confirmed = await confirmStatsExport(
      context: context,
      title: 'Export all barangays',
      message: 'Create a Google Sheet containing stats for all barangays?',
    );
    if (confirmed != true || !mounted) return;
    showExportLoading(context, 'Exporting all barangays...');
    await _runExport(
      () => GoogleSheetsService.instance.exportAllBarangayStats(
        List<BarangayUserStat>.from(_original),
      ),
      'Exported all barangays',
    );
  }

  Future<void> _confirmAndExportFiltered() async {
    final confirmed = await confirmStatsExport(
      context: context,
      title: 'Export filtered results',
      message:
          'Create a Google Sheet containing stats for the ${_filtered.length} matching barangays?',
    );
    if (confirmed != true || !mounted) return;
    showExportLoading(context, 'Exporting filtered results...');
    await _runExport(
      () => GoogleSheetsService.instance.exportAllBarangayStats(
        List<BarangayUserStat>.from(_filtered),
      ),
      'Exported filtered results',
    );
  }

  Future<void> _runExport(
    Future<Map<String, dynamic>> Function() export,
    String successMessage,
  ) async {
    setState(() => _exporting = true);
    try {
      final resp = await export();
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      setState(() => _exporting = false);

      final url = (resp['url'] as String? ?? '');
      if (url.isNotEmpty) {
        SnackbarUtils.show(
          context,
          successMessage,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () {
              final uri = Uri.tryParse(url);
              if (uri != null) launchUrlString(url);
            },
          ),
          duration: const Duration(seconds: 5),
        );
      } else {
        SnackbarUtils.show(context, 'Export completed. No URL returned.');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading dialog
      if (mounted) {
        setState(() => _exporting = false);
        SnackbarUtils.showError(context, 'Export failed: ${e.toString()}');
      }
    }
  }
}

class _RowStat extends StatelessWidget {
  final BarangayUserStat stat;
  final int maxTotal;
  final ResponsiveInfo info;

  const _RowStat({
    required this.stat,
    required this.maxTotal,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final verified = stat.verified;
    final unverified = stat.unverified;
    final ratio = maxTotal > 0 ? (stat.total / maxTotal) : 0.0;

    final logo = _lookupBarangayLogo(stat.barangay);

    return Semantics(
      button: true,
      label:
          '${stat.barangay}: ${stat.total} total users, ${stat.verified} verified, ${stat.unverified} unverified',
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: info.scale(12),
            vertical: info.scale(8),
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: info.scale(8)),
                child: _buildLogoWidget(context, logo, stat.barangay, info),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  stat.barangay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: info.scaleFont(14)),
                ),
              ),
              SizedBox(width: info.scale(12)),
              Expanded(
                flex: 5,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barMaxWidth = constraints.maxWidth;
                    final barWidth = barMaxWidth * ratio.clamp(0.0, 1.0);
                    final verifiedWidth = stat.total > 0
                        ? (barWidth * (verified / stat.total))
                        : 0.0;
                    final unverifiedWidth = stat.total > 0
                        ? (barWidth * (unverified / stat.total))
                        : 0.0;
                    return Stack(
                      children: [
                        Container(
                          width: barMaxWidth,
                          height: info.scale(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Row(
                          children: [
                            if (verifiedWidth > 0)
                              Container(
                                width: verifiedWidth,
                                height: info.scale(16),
                                decoration: BoxDecoration(
                                  color: kVerifiedColor,
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(6),
                                  ),
                                ),
                              ),
                            if (unverifiedWidth > 0)
                              Container(
                                width: unverifiedWidth,
                                height: info.scale(16),
                                decoration: BoxDecoration(
                                  color: kUnverifiedColor,
                                  borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(width: info.scale(12)),
              SizedBox(
                width: info.scale(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stat.total}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: info.scaleFont(13),
                      ),
                    ),
                    Text(
                      '${stat.verified}/${stat.unverified}',
                      style: TextStyle(
                        fontSize: info.scaleFont(11),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final logo = _lookupBarangayLogo(stat.barangay);
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            info.scale(16),
            info.scale(12),
            info.scale(16),
            info.scale(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: info.scale(40),
                height: info.scale(4),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: info.scale(12)),
              SizedBox(
                width: info.scale(84),
                height: info.scale(84),
                child: _buildLogoWidget(ctx, logo, stat.barangay, info),
              ),
              SizedBox(height: info.scale(12)),
              Text(
                stat.barangay,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: info.scaleFont(18),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: info.scale(8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        '${stat.total}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: info.scaleFont(16),
                        ),
                      ),
                      Text(
                        'Total',
                        style: TextStyle(fontSize: info.scaleFont(12)),
                      ),
                    ],
                  ),
                  SizedBox(width: info.scale(24)),
                  Column(
                    children: [
                      Text(
                        '${stat.verified}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: info.scaleFont(16),
                          color: kVerifiedColor,
                        ),
                      ),
                      Text(
                        'Verified',
                        style: TextStyle(fontSize: info.scaleFont(12)),
                      ),
                    ],
                  ),
                  SizedBox(width: info.scale(24)),
                  Column(
                    children: [
                      Text(
                        '${stat.unverified}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: info.scaleFont(16),
                          color: kUnverifiedColor,
                        ),
                      ),
                      Text(
                        'Unverified',
                        style: TextStyle(fontSize: info.scaleFont(12)),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: info.scale(16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop(); // close sheet

                        showExportLoading(
                          context,
                          'Exporting ${stat.barangay}...',
                        );

                        try {
                          final resp = await GoogleSheetsService.instance
                              .exportBarangayStat(stat);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(); // close progress

                          final url = (resp['url'] as String? ?? '');
                          final exportedBarangay =
                              (resp['exportedBarangay'] as String?);

                          if (url.isNotEmpty) {
                            final message =
                                exportedBarangay != null &&
                                    exportedBarangay.isNotEmpty
                                ? 'Exported Barangay: $exportedBarangay'
                                : 'Exported to Google Sheets';
                            SnackbarUtils.show(
                              context,
                              message,
                              action: SnackBarAction(
                                label: 'Open',
                                textColor: Colors.white,
                                onPressed: () {
                                  final uri = Uri.tryParse(url);
                                  if (uri != null) launchUrlString(url);
                                },
                              ),
                              duration: const Duration(seconds: 4),
                            );
                          } else {
                            SnackbarUtils.show(
                              context,
                              'Export completed. No URL returned.',
                              duration: const Duration(seconds: 3),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.of(context).pop(); // close progress
                            SnackbarUtils.showError(
                              context,
                              'Export failed: ${e.toString()}',
                            );
                          }
                        }
                      },
                      child: const Text('Export to Google Sheet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Lookup logo path (asset or URL) by barangay name using BarangayService metadata.
  // fast and synchronous (no network).
  String? _lookupBarangayLogo(String barangayName) {
    final svc = BarangayService();
    if (!svc.isLoaded) return null;
    return svc.logoForName(barangayName);
  }

  // Build logo widget: network / asset / initials fallback.
  Widget _buildLogoWidget(
    BuildContext context,
    String? logo,
    String name,
    ResponsiveInfo info,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final double size = info.scale(40);
    final int cacheW = context.cacheWidthForImage(size);

    Widget initialsAvatar() {
      final parts = name.split(' ');
      final initials = parts
          .fold<String>('', (acc, p) => acc + (p.isEmpty ? '' : p[0]))
          .toUpperCase();
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: colorScheme.primary,
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(12)),
        ),
      );
    }

    if (logo == null || logo.isEmpty) {
      return SizedBox(width: size, height: size, child: initialsAvatar());
    }
    // Network image
    if (logo.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheW,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) => initialsAvatar(),
        ),
      );
    }

    // Asset image (local)
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheW,
          errorBuilder: (_, _, _) => initialsAvatar(),
        ),
      );
    } catch (_) {
      return SizedBox(width: size, height: size, child: initialsAvatar());
    }
  }
}
