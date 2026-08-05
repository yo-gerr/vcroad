import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/stats.dart';
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/data/repositories/google_sheets.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:vcroad/core/utils/debouncer/debouncer.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/core/utils/format/date_time.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/features/home/widgets/stats_common.dart';

/// Lightweight in-file model for barangay report stats.
/// If you already have a shared model, replace/remove this

class BarangayReportStats extends StatefulWidget {
  final List<BarangayReportStat> stats;
  final int topLimit;
  final DateTime timestamp;
  // Optional per-barangay export handler. If provided, it will be called with
  // the BarangayReportStat for the selected barangay. Should return a Future
  // so the UI can show progress.
  final Future<void> Function(BarangayReportStat)? onExport;

  const BarangayReportStats({
    super.key,
    required this.stats,
    this.topLimit = 20,
    required this.timestamp,
    this.onExport,
  });

  @override
  State<BarangayReportStats> createState() => _BarangayReportStatsState();
}

class _BarangayReportStatsState extends State<BarangayReportStats> {
  late List<BarangayReportStat> _original;
  late List<BarangayReportStat> _filtered;
  String _query = '';
  final Debouncer _debouncer = Debouncer(const Duration(milliseconds: 250));
  bool _exporting = false;

  int _filteredTotal = 0;
  int _filteredVerified = 0;
  int _filteredResolved = 0;
  int _filteredFlagged = 0;

  @override
  void initState() {
    super.initState();
    _original = List<BarangayReportStat>.from(widget.stats);
    _filtered = _original;
    _computeFilteredTotals();
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
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _computeFilteredTotals() {
    final agg = _filtered.fold<List<int>>(
      [0, 0, 0, 0],
      (acc, s) => [
        acc[0] + s.total,
        acc[1] + s.verified,
        acc[2] + s.resolved,
        acc[3] + s.flagged,
      ],
    );
    _filteredTotal = agg[0];
    _filteredVerified = agg[1];
    _filteredResolved = agg[2];
    _filteredFlagged = agg[3];
  }

  void _onSearchChanged(String q) {
    _debouncer.call(() {
      if (!mounted) return;
      setState(() {
        _query = q.trim().toLowerCase();
        if (_query.isEmpty) {
          _filtered = _original;
        } else {
          _filtered = _original
              .where((s) => s.barangay.toLowerCase().contains(_query))
              .toList();
        }
        _computeFilteredTotals();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ResponsiveInfo info = context.responsive;
    final colorScheme = Theme.of(context).colorScheme;
    final sorted = List<BarangayReportStat>.from(_filtered)
      // remove zero-total barangays (hide rows with zero reports)
      ..removeWhere((s) => s.total == 0)
      ..sort((a, b) => b.total.compareTo(a.total));

    // show all non-zero rows (no top-N aggregation)
    final visible = sorted;

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
          'Reports per Barangay',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: _exporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: _exporting ? null : _onExportPressed,
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
                      'Showing ${visible.length}${_showingOf(visible.length)}',
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
                  _summaryColumn(
                    'Total reports',
                    '$_filteredTotal',
                    info,
                    align: CrossAxisAlignment.start,
                  ),
                  _summaryColumn(
                    'Verified',
                    '$_filteredVerified',
                    info,
                    color: Colors.green,
                  ),
                  _summaryColumn(
                    'Resolved',
                    '$_filteredResolved',
                    info,
                    color: Colors.blue,
                  ),
                  _summaryColumn(
                    'Flagged',
                    '$_filteredFlagged',
                    info,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            SizedBox(height: info.scale(12)),
            StatsLegend(
              items: const [
                ('Verified', Colors.green),
                ('Resolved', Colors.blue),
                ('Flagged', Colors.red),
                ('Pending', Colors.grey),
              ],
            ),
            SizedBox(height: info.scale(12)),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final s = visible[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: info.scale(6)),
                    child: _RowStat(
                      stat: s,
                      maxTotal: maxTotal,
                      info: info,
                      onExport: widget.onExport,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: info.scale(12)),
            Text(
              'as of ${DateFormatUtils.formatFriendly(widget.timestamp)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: info.scaleFont(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _showingOf(int totalEntries) {
    if (_query.isEmpty) return ' of $totalEntries';
    return ' of $totalEntries';
  }

  Widget _summaryColumn(
    String label,
    String value,
    ResponsiveInfo info, {
    Color color = Colors.grey,
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: info.scaleFont(12),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: info.scale(6)),
        Text(
          value,
          style: TextStyle(
            fontSize: info.scaleFont(18),
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _exportBarangay(BarangayReportStat s) async {
    final confirmed = await confirmStatsExport(
      context: context,
      title: 'Export ${s.barangay}',
      message:
          'Create a Google Sheet containing report stats for ${s.barangay}?',
    );
    if (confirmed != true) return;

    if (!mounted) return;
    showExportLoading(context, 'Exporting...');

    try {
      final result = await GoogleSheetsService.instance
          .exportBarangayReportStat(
            barangay: s.barangay,
            total: s.total,
            verified: s.verified,
            resolved: s.resolved,
            flagged: s.flagged,
          );
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      final url = result['url'] as String? ?? '';
      if (url.isNotEmpty) {
        SnackbarUtils.show(
          context,
          'Exported ${s.barangay}',
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
        SnackbarUtils.show(context, 'Exported ${s.barangay}');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      if (mounted) SnackbarUtils.showError(context, 'Export failed: $e');
    }
  }

  Future<void> _onExportPressed() async {
    if (_filtered.isEmpty) {
      SnackbarUtils.show(context, 'No barangay data to export');
      return;
    }
    final confirmed = await confirmStatsExport(
      context: context,
      title: 'Export all visible barangays',
      message:
          'Create a Google Sheet for the ${_filtered.length} visible barangays?',
    );
    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _exporting = true);
    showExportLoading(context, 'Exporting...');

    try {
      final rows = _filtered
          .map(
            (s) => {
              'barangay': s.barangay,
              'total': s.total,
              'verified': s.verified,
              'resolved': s.resolved,
              'flagged': s.flagged,
            },
          )
          .toList();
      final result = await GoogleSheetsService.instance
          .exportAllBarangayReportStats(rows);
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      setState(() => _exporting = false);
      final url = result['url'] as String? ?? '';
      if (url.isNotEmpty) {
        SnackbarUtils.show(
          context,
          'Export completed',
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
        SnackbarUtils.show(context, 'Export completed');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      setState(() => _exporting = false);
      if (mounted) SnackbarUtils.showError(context, 'Export failed: $e');
    }
  }
}

class _RowStat extends StatelessWidget {
  final BarangayReportStat stat;
  final int maxTotal;
  final ResponsiveInfo info;
  final Future<void> Function(BarangayReportStat)? onExport;

  const _RowStat({
    required this.stat,
    required this.maxTotal,
    required this.info,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final verified = stat.verified.toDouble();
    final resolved = stat.resolved.toDouble();
    final flagged = stat.flagged.toDouble();
    final pending = stat.pending.toDouble();
    final total = stat.total.toDouble().clamp(0.0, double.infinity);

    final ratio = maxTotal > 0 ? (stat.total / maxTotal) : 0.0;
    final barMaxWidth = info.screenWidth * 0.45; // reasonable proportion
    final barWidth = barMaxWidth * ratio.clamp(0.0, 1.0);
    final verifiedWidth = total > 0 ? (barWidth * (verified / total)) : 0.0;
    final resolvedWidth = total > 0 ? (barWidth * (resolved / total)) : 0.0;
    final flaggedWidth = total > 0 ? (barWidth * (flagged / total)) : 0.0;
    final pendingWidth = total > 0 ? (barWidth * (pending / total)) : 0.0;

    final logo = _lookupBarangayLogo(stat.barangay);

    return Semantics(
      button: true,
      label:
          '${stat.barangay}: ${stat.total} total reports, ${stat.verified} verified, ${stat.resolved} resolved, ${stat.flagged} flagged',
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
                child: Stack(
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
                              color: Colors.green,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(6),
                              ),
                            ),
                          ),
                        if (resolvedWidth > 0)
                          Container(
                            width: resolvedWidth,
                            height: info.scale(16),
                            decoration: BoxDecoration(color: Colors.blue),
                          ),
                        if (flaggedWidth > 0)
                          Container(
                            width: flaggedWidth,
                            height: info.scale(16),
                            decoration: BoxDecoration(color: Colors.red),
                          ),
                        if (pendingWidth > 0)
                          Container(
                            width: pendingWidth,
                            height: info.scale(16),
                            decoration: BoxDecoration(color: Colors.grey),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: info.scale(12)),
              SizedBox(
                width: info.scale(64),
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
                    SizedBox(height: info.scale(4)),
                    Text(
                      '${stat.verified}/${stat.resolved}/${stat.flagged}',
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
                  _countColumn(ctx, 'Total', stat.total.toString(), info),
                  SizedBox(width: info.scale(18)),
                  _countColumn(
                    ctx,
                    'Pending',
                    stat.pending.toString(),
                    info,
                    color: Colors.grey,
                  ),
                  SizedBox(width: info.scale(18)),
                  _countColumn(
                    ctx,
                    'Verified',
                    stat.verified.toString(),
                    info,
                    color: Colors.green,
                  ),
                  SizedBox(width: info.scale(18)),
                  _countColumn(
                    ctx,
                    'Resolved',
                    stat.resolved.toString(),
                    info,
                    color: Colors.blue,
                  ),
                  SizedBox(width: info.scale(18)),
                  _countColumn(
                    ctx,
                    'Flagged',
                    stat.flagged.toString(),
                    info,
                    color: Colors.red,
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
                        if (onExport != null) {
                          // parent-provided handler
                          try {
                            showExportLoading(context, 'Exporting...');
                            await onExport!(stat);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            SnackbarUtils.show(
                              context,
                              'Exported ${stat.barangay}',
                            );
                          } catch (e) {
                            if (context.mounted) Navigator.of(context).pop();
                            if (context.mounted) {
                              SnackbarUtils.showError(
                                context,
                                'Export failed: $e',
                              );
                            }
                          }
                        } else {
                          // default built-in export
                          await (context as Element)
                              .findAncestorStateOfType<
                                _BarangayReportStatsState
                              >()
                              ?._exportBarangay(stat);
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

  Widget _countColumn(
    BuildContext context,
    String label,
    String value,
    ResponsiveInfo info, {
    Color? color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: info.scaleFont(16),
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: info.scale(4)),
        Text(label, style: TextStyle(fontSize: info.scaleFont(12))),
      ],
    );
  }

  // Lookup logo path (asset or URL) by barangay name using BarangayService metadata.
  String? _lookupBarangayLogo(String barangayName) {
    final svc = BarangayService();
    if (!svc.isLoaded) return null;
    return svc.logoForName(barangayName);
  }

  Widget _buildLogoWidget(
    BuildContext context,
    String? logo,
    String name,
    ResponsiveInfo info,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final double size = info.scale(40);
    final int cacheW = (size * MediaQuery.of(context).devicePixelRatio).toInt();

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
