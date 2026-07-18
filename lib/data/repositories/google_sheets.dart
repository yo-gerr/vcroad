import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vcroad/core/utils/web/web_download.dart';
import 'package:vcroad/data/models/stats.dart';

/// Exports stats to CSV files locally (replaces old Google Sheets Cloud Function).
/// On web: triggers a browser download.
/// On native: writes to the system temp directory and returns the file path.
class GoogleSheetsService {
  GoogleSheetsService._();
  static final GoogleSheetsService instance = GoogleSheetsService._();

  Future<Map<String, dynamic>> exportBarangayStat(BarangayUserStat stat) async {
    final csv = _generateCsv([
      [
        'Barangay',
        'Total Users',
        'Verified',
        'Unverified',
        'Generated At',
      ],
      [
        stat.barangay,
        stat.total.toString(),
        stat.verified.toString(),
        stat.unverified.toString(),
        DateTime.now().toIso8601String(),
      ],
    ]);
    final filename =
        'barangay_user_stat_${stat.barangay}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return _exportCsv(csv, filename);
  }

  Future<Map<String, dynamic>> exportAllBarangayStats(
    List<BarangayUserStat> stats,
  ) async {
    final rows = <List<String>>[
      ['Barangay', 'Total Users', 'Verified', 'Unverified'],
    ];
    for (final s in stats) {
      rows.add([
        s.barangay,
        s.total.toString(),
        s.verified.toString(),
        s.unverified.toString(),
      ]);
    }
    final csv = _generateCsv(rows);
    final filename =
        'barangay_user_stats_${DateTime.now().millisecondsSinceEpoch}.csv';
    return _exportCsv(csv, filename);
  }

  Future<Map<String, dynamic>> exportBarangayReportStat({
    required String barangay,
    required int total,
    required int verified,
    required int resolved,
    required int flagged,
  }) async {
    final pending = (total - verified - resolved - flagged).clamp(0, total);
    final csv = _generateCsv([
      [
        'Barangay',
        'Total Reports',
        'Verified',
        'Unverified',
        'Resolved',
        'Flagged',
        'Generated At',
      ],
      [
        barangay,
        total.toString(),
        verified.toString(),
        pending.toString(),
        resolved.toString(),
        flagged.toString(),
        DateTime.now().toIso8601String(),
      ],
    ]);
    final filename =
        'barangay_report_stat_${barangay}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return _exportCsv(csv, filename);
  }

  Future<Map<String, dynamic>> exportAllBarangayReportStats(
    List<Map<String, dynamic>> reportStats,
  ) async {
    final rows = <List<String>>[
      ['Barangay', 'Total Reports', 'Verified', 'Unverified', 'Resolved', 'Flagged'],
    ];
    for (final s in reportStats) {
      final total = s['total'] as int? ?? 0;
      final verified = s['verified'] as int? ?? 0;
      final resolved = s['resolved'] as int? ?? 0;
      final flagged = s['flagged'] as int? ?? 0;
      final pending = (total - verified - resolved - flagged).clamp(0, total);
      rows.add([
        s['barangay'] as String? ?? '',
        total.toString(),
        verified.toString(),
        pending.toString(),
        resolved.toString(),
        flagged.toString(),
      ]);
    }
    final csv = _generateCsv(rows);
    final filename =
        'barangay_report_stats_${DateTime.now().millisecondsSinceEpoch}.csv';
    return _exportCsv(csv, filename);
  }

  static String _generateCsv(List<List<String>> rows) {
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(row.map(_csvField).join(','));
    }
    return buf.toString();
  }

  static String _csvField(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static Future<Map<String, dynamic>> _exportCsv(
    String csv,
    String filename,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    if (kIsWeb) {
      openBytesInNewTab(bytes, filename, autoDownload: true);
      return {'url': ''};
    }
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return {'url': file.path};
  }
}
