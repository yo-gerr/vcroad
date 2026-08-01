import 'package:flutter/material.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/core/utils/format/date_time.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class ReportStats extends StatelessWidget {
  final Map<ReportCategory, int> reportCounts;
  final VoidCallback? onBarangayTap;
  final Future<void> Function()? onExportBarangay;
  final DateTime timestamp;

  const ReportStats({
    super.key,
    required this.reportCounts,
    this.onBarangayTap,
    this.onExportBarangay,
    required this.timestamp,
  });

  factory ReportStats.fromDynamic({
    Key? key,
    required Map<dynamic, int> rawCounts,
    VoidCallback? onBarangayTap,
    required DateTime timestamp,
  }) {
    final Map<ReportCategory, int> normalized = {};
    for (final entry in rawCounts.entries) {
      final key = entry.key;
      final value = entry.value;
      ReportCategory? cat;
      if (key is ReportCategory) {
        cat = key;
      } else if (key is String) {
        final lower = key.toLowerCase().trim();
        try {
          cat = ReportCategory.values.firstWhere(
            (e) =>
                e.name.toLowerCase() == lower ||
                e.name.toLowerCase() == lower.replaceAll('_', ''),
          );
        } catch (_) {
          try {
            cat = ReportCategory.values.firstWhere(
              (e) => e.label.toLowerCase() == lower,
            );
          } catch (_) {
          }
        }
      }
      if (cat != null) normalized[cat] = (normalized[cat] ?? 0) + value;
    }

    return ReportStats(
      key: key,
      reportCounts: normalized,
      onBarangayTap: onBarangayTap,
      timestamp: timestamp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final cs = Theme.of(context).colorScheme;

    final entries = reportCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final titleStyle = TextStyle(
      color: cs.primary,
      fontSize: info.scaleFont(20),
      fontWeight: FontWeight.bold,
    );
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: info.scaleFont(14),
      color: cs.onSurfaceVariant,
    );
    final labelStyle = TextStyle(
      fontSize: info.scaleFont(14),
      color: cs.onSurface,
    );
    final countStyle = TextStyle(
      fontSize: info.scaleFont(14),
      fontWeight: FontWeight.bold,
      color: cs.primary,
    );

    return Container(
      padding: EdgeInsets.all(info.scale(20)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Reports', style: titleStyle),
          SizedBox(height: info.scale(16)),
          Row(
            children: [
              Expanded(child: Text('Type', style: headerStyle)),
              Text('Count', style: headerStyle),
            ],
          ),
          Divider(height: info.scale(20), thickness: 1),
          ...entries.map((e) {
            final cat = e.key;
            final count = e.value;
            return Padding(
              padding: EdgeInsets.symmetric(vertical: info.scale(8)),
              child: Row(
                children: [
                  SizedBox(
                    width: info.scale(28),
                    height: info.scale(28),
                    child: Image.asset(cat.asset, fit: BoxFit.contain),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(child: Text(cat.label, style: labelStyle)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: info.scale(12),
                      vertical: info.scale(4),
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$count', style: countStyle),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: info.scale(12)),
          if (onBarangayTap != null)
            OutlinedButton(
              onPressed: onBarangayTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Per Barangay',
                style: TextStyle(fontSize: info.scaleFont(14)),
              ),
            )
          else if (onExportBarangay != null)
            OutlinedButton.icon(
              onPressed: () => onExportBarangay!(),
              icon: Icon(
                Icons.download_outlined,
                size: info.scale(16),
                color: cs.primary,
              ),
              label: Text(
                'Export',
                style: TextStyle(
                  fontSize: info.scaleFont(14),
                  color: cs.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          SizedBox(height: info.scale(8)),
          Text(
            'as of ${DateFormatUtils.formatFriendly(timestamp)}',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: info.scaleFont(12),
            ),
          ),
        ],
      ),
    );
  }
}
