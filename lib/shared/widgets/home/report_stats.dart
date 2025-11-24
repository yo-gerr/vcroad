import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/report.dart';
import 'package:vcroad_v2/shared/utils/format/date_time.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

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
        // try name match
        try {
          cat = ReportCategory.values.firstWhere(
            (e) =>
                e.name.toLowerCase() == lower ||
                e.name.toLowerCase() == lower.replaceAll('_', ''),
          );
        } catch (_) {
          // try label match
          try {
            cat = ReportCategory.values.firstWhere(
              (e) => e.label.toLowerCase() == lower,
            );
          } catch (_) {
            // ignore unknown
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

    // Convert entries once
    final entries = reportCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final titleStyle = TextStyle(
      color: const Color(0xFF1565C0),
      fontSize: info.scaleFont(20),
      fontWeight: FontWeight.bold,
    );
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: info.scaleFont(14),
      color: Colors.grey.shade700,
    );
    final labelStyle = TextStyle(
      fontSize: info.scaleFont(14),
      color: Colors.grey.shade800,
    );
    final countStyle = TextStyle(
      fontSize: info.scaleFont(14),
      fontWeight: FontWeight.bold,
      color: const Color(0xFF1565C0),
    );

    return Container(
      padding: EdgeInsets.all(info.scale(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            // Use Image.asset directly — make sure assets are precached in parent
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
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
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
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0)),
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
                color: const Color(0xFF1565C0),
              ),
              label: Text(
                'Export',
                style: TextStyle(
                  fontSize: info.scaleFont(14),
                  color: const Color(0xFF1565C0),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1565C0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          SizedBox(height: info.scale(8)),
          Text(
            'as of ${DateFormatUtils.formatFriendly(timestamp)}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: info.scaleFont(12),
            ),
          ),
        ],
      ),
    );
  }
}
