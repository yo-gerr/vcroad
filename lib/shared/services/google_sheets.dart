import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vcroad_v2/shared/models/stats.dart';

class GoogleSheetsService {
  GoogleSheetsService._();
  static final GoogleSheetsService instance = GoogleSheetsService._();

  static const String _endpoint =
      'https://us-central1-vcroad-a0022.cloudfunctions.net/sheetsProxy';

  // Optional API key that matches EXPORT_API_KEY in the Apps Script. Set via
  // a secure config before releasing. Empty string disables sending.
  static const String _apiKey = '';

  // Returns a map: { 'url': String, 'exportedBarangay': String? }
  Future<Map<String, dynamic>> exportBarangayStat(BarangayUserStat stat) async {
    if (_endpoint.isEmpty) {
      throw Exception(
        'SHEETS_WEBHOOK_URL is not configured. Provide a server endpoint that creates a Google Sheet.',
      );
    }

    final payload = {
      'barangay': stat.barangay,
      'total': stat.total,
      'verified': stat.verified,
      'unverified': stat.unverified,
      'generatedAt': DateTime.now().toIso8601String(),
    };

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
        final url = body is Map && body['url'] is String ? body['url'] : '';
        final exportedBarangay =
            body is Map && body['exportedBarangay'] is String
            ? body['exportedBarangay']
            : null;
        return {'url': url, 'exportedBarangay': exportedBarangay};
      } else {
        throw Exception(
          'Export failed (status ${resp.statusCode}): ${resp.body}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleSheetsService export error: $e');
      rethrow;
    }
  }

  // Bulk export: returns map { 'url': String }
  Future<Map<String, dynamic>> exportAllBarangayStats(
    List<BarangayUserStat> stats,
  ) async {
    if (_endpoint.isEmpty) {
      throw Exception(
        'SHEETS_WEBHOOK_URL is not configured. Provide a server endpoint that creates a Google Sheet.',
      );
    }

    final payload = {
      'kind': 'bulk_export',
      'generatedAt': DateTime.now().toIso8601String(),
      'rows': stats
          .map(
            (s) => {
              'barangay': s.barangay,
              'total': s.total,
              'verified': s.verified,
              'unverified': s.unverified,
            },
          )
          .toList(),
    };

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
        final url = body is Map && body['url'] is String ? body['url'] : '';
        return {'url': url};
      } else {
        throw Exception(
          'Export failed (status ${resp.statusCode}): ${resp.body}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleSheetsService.exportAll error: $e');
      rethrow;
    }
  }

  /// Export report stats for a single barangay
  /// Converts report stat to the format expected by the Google Apps Script
  Future<Map<String, dynamic>> exportBarangayReportStat({
    required String barangay,
    required int total,
    required int verified,
    required int resolved,
    required int flagged,
  }) async {
    if (_endpoint.isEmpty) {
      throw Exception('SHEETS_WEBHOOK_URL is not configured.');
    }

    final pending = (total - verified - resolved - flagged).clamp(0, total);

    final payload = {
      'exportType': 'report', // ensure Apps Script uses report headers
      'barangay': barangay,
      'total': total,
      'verified': verified,
      'unverified': pending,
      'resolved': resolved,
      'flagged': flagged,
      'generatedAt': DateTime.now().toIso8601String(),
      if (_apiKey.isNotEmpty) 'apiKey': _apiKey,
    };

    try {
      final client = http.Client();
      try {
        final resp = await client
            .post(
              Uri.parse(_endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));
        // normal response handling below
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
          final url = body is Map && body['url'] is String ? body['url'] : '';
          final exportedBarangay =
              body is Map && body['exportedBarangay'] is String
              ? body['exportedBarangay']
              : null;
          return {'url': url, 'exportedBarangay': exportedBarangay};
        } else {
          throw Exception(
            'Export failed (status ${resp.statusCode}): ${resp.body}',
          );
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleSheetsService.exportReportStat error: $e');
      }
      rethrow;
    }
  }

  /// Bulk export report stats for multiple barangays
  Future<Map<String, dynamic>> exportAllBarangayReportStats(
    List<Map<String, dynamic>> reportStats,
  ) async {
    if (_endpoint.isEmpty) {
      throw Exception(
        'SHEETS_WEBHOOK_URL is not configured. Provide a server endpoint that creates a Google Sheet.',
      );
    }

    final payload = {
      'kind': 'bulk_export',
      'generatedAt': DateTime.now().toIso8601String(),
      'rows': reportStats.map((s) {
        final total = s['total'] as int? ?? 0;
        final verified = s['verified'] as int? ?? 0;
        final resolved = s['resolved'] as int? ?? 0;
        final flagged = s['flagged'] as int? ?? 0;
        final pending = (total - verified - resolved - flagged).clamp(0, total);

        return {
          'barangay': s['barangay'] as String? ?? '',
          'total': total,
          'verified': verified,
          'unverified': pending,
        };
      }).toList(),
    };

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
        final url = body is Map && body['url'] is String ? body['url'] : '';
        return {'url': url};
      } else {
        throw Exception(
          'Export failed (status ${resp.statusCode}): ${resp.body}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleSheetsService.exportAllReportStats error: $e');
      }
      rethrow;
    }
  }
}
