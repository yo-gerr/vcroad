import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/data/repositories/storage.dart';

class ReportService {
  ReportService._();
  static final instance = ReportService._();

  final _firestore = FirebaseFirestore.instance;
  final SupabaseStorageService _storage = SupabaseStorageService.instance;

  // In-memory cache for report storage paths -> public URLs
  final Map<String, String> _urlCache = {};

  Future<Map<String, String>> uploadReportMedia({
    required String userId,
    required String reportId,
    required MediaType mediaType,
    required dynamic mediaData,
    int maxRetries = 3,
  }) async {
    final ext = mediaType == MediaType.photo ? 'jpg' : 'mp4';
    final path = 'reports/$userId/$reportId/media.$ext';
    Uint8List? dataBytes;
    if (mediaType == MediaType.photo) {
      if (mediaData is Uint8List) {
        dataBytes = mediaData;
      } else if (mediaData is String) {
        dataBytes = await compute<_CompressArgs, Uint8List?>(
          _compressImageIsolate,
          _CompressArgs(path: mediaData, quality: 80, maxWidth: 1920),
        );
      }
    } else {
      if (mediaData is Uint8List) {
        dataBytes = mediaData;
      } else if (mediaData is String) {
        dataBytes = await compute<String, Uint8List?>(
          _readFileAsBytesIsolate,
          mediaData,
        );
      }
    }
    if (dataBytes == null) {
      throw ArgumentError('Unsupported media data or compression failed');
    }
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final contentType = mediaType == MediaType.photo ? 'image/jpeg' : 'video/mp4';
        final publicUrl = await _storage.uploadBytes(
          path: path,
          bytes: dataBytes,
          contentType: contentType,
        );
        _urlCache[path] = publicUrl;
        return {'mediaPath': path, 'mediaUrl': publicUrl};
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw Exception('Upload failed after $maxRetries attempts');
  }

  /// Submit a new report with media upload
  Future<String> submitReport(ReportData report) async {
    try {
      // Use batch write for atomicity
      final batch = _firestore.batch();
      final docRef = _firestore.collection('reports').doc(report.reportId);

      batch.set(docRef, report.toFirestore());

      await batch.commit();

      if (kDebugMode) {
        print('✅ Report ${report.reportId} submitted successfully');
      }

      return report.reportId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error submitting report: $e');
      }
      rethrow;
    }
  }

  /// Fetch user reports with pagination support
  Stream<List<ReportData>> getUserReports(
    String userId, {
    int limit = 20,
    bool activeOnly = true,
  }) {
    Query query = _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    // Attach inline error logging for index/auth issues and keep stream alive.
    return query
        .limit(limit)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            if (error is FirebaseException) {
              debugPrint(
                '[Firestore][getUserReports] FirebaseException code=${error.code} message=${error.message}',
              );
            } else {
              debugPrint('[Firestore][getUserReports] Stream error: $error');
            }
            final msg = error.toString().toLowerCase();
            if (msg.contains('index')) {
              debugPrint(
                '[Firestore][getUserReports] Index error detected — check composite indexes for "reports" queries.',
              );
            }
            if (msg.contains('credentials_missing') ||
                msg.contains('unauthenticated')) {
              debugPrint(
                '[Firestore][getUserReports] Authentication error — ensure Firebase credentials / CLI login and correct rules.',
              );
            }
          }
        }, test: (_) => true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportData.fromFirestore(doc))
              .toList(),
        );
  }

  /// Fetch all reports with filtering and pagination (for admin/sysadmin)
  Stream<List<ReportData>> getAllReports({
    int limit = 50,
    ReportStatus? statusFilter,
    ReportCategory? categoryFilter,
    String? barangayFilter,
    bool activeOnly = true,
  }) {
    Query query = _firestore.collection('reports');

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    // Apply status filters
    if (statusFilter != null) {
      switch (statusFilter) {
        case ReportStatus.pending:
          query = query
              .where('isVerified', isEqualTo: false)
              .where('isResolved', isEqualTo: false)
              .where('isFlagged', isEqualTo: false);
          break;
        case ReportStatus.verified:
          query = query
              .where('isVerified', isEqualTo: true)
              .where('isResolved', isEqualTo: false);
          break;
        case ReportStatus.resolved:
          query = query.where('isResolved', isEqualTo: true);
          break;
        case ReportStatus.flagged:
          query = query.where('isFlagged', isEqualTo: true);
          break;
      }
    }

    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter.name);
    }

    if (barangayFilter != null && barangayFilter.isNotEmpty) {
      query = query.where('barangay', isEqualTo: barangayFilter);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            if (error is FirebaseException) {
              debugPrint(
                '[Firestore][getAllReports] FirebaseException code=${error.code} message=${error.message}',
              );
            } else {
              debugPrint('[Firestore][getAllReports] Stream error: $error');
            }
            final msg = error.toString().toLowerCase();
            if (msg.contains('index')) {
              debugPrint(
                '[Firestore][getAllReports] Index issue detected — add composite indexes for the applied where() + orderBy() fields.',
              );
            }
            if (msg.contains('credentials_missing') ||
                msg.contains('unauthenticated')) {
              debugPrint(
                '[Firestore][getAllReports] Auth issue — verify Firebase auth state / CLI credentials.',
              );
            }
          }
        }, test: (_) => true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportData.fromFirestore(doc))
              .toList(),
        );
  }

  /// Fetch all reports for non-admin users (excludes resolved & flagged).
  Stream<List<ReportData>> getAllReportsForNonAdmin({
    int limit = 50,
    ReportCategory? categoryFilter,
    String? barangayFilter,
    bool activeOnly = true,
  }) {
    Query query = _firestore.collection('reports');

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    // Always exclude resolved & flagged for non-admin users
    query = query
        .where('isResolved', isEqualTo: false)
        .where('isFlagged', isEqualTo: false);

    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter.name);
    }

    if (barangayFilter != null && barangayFilter.isNotEmpty) {
      query = query.where('barangay', isEqualTo: barangayFilter);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            debugPrint(
              '[Firestore][getAllReportsForNonAdmin] Stream error: $error',
            );
          }
        }, test: (_) => true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportData.fromFirestore(doc))
              .toList(),
        );
  }

  /// Fetch reports by status with pagination
  Stream<List<ReportData>> getReportsByStatus({
    bool? isVerified,
    bool? isResolved,
    bool? isFlagged,
    int limit = 50,
    bool activeOnly = true,
  }) {
    Query query = _firestore.collection('reports');

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (isVerified != null) {
      query = query.where('isVerified', isEqualTo: isVerified);
    }
    if (isResolved != null) {
      query = query.where('isResolved', isEqualTo: isResolved);
    }
    if (isFlagged != null) {
      query = query.where('isFlagged', isEqualTo: isFlagged);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            if (error is FirebaseException) {
              debugPrint(
                '[Firestore][getReportsByStatus] FirebaseException code=${error.code} message=${error.message}',
              );
            } else {
              debugPrint(
                '[Firestore][getReportsByStatus] Stream error: $error',
              );
            }
            final msg = error.toString().toLowerCase();
            if (msg.contains('index')) {
              debugPrint(
                '[Firestore][getReportsByStatus] Missing index for combined where/orderBy query.',
              );
            }
          }
        }, test: (_) => true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportData.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a single report by ID
  Future<ReportData?> getReportById(String reportId) async {
    try {
      final doc = await _firestore.collection('reports').doc(reportId).get();
      if (!doc.exists) return null;
      return ReportData.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching report $reportId: $e');
      }
      return null;
    }
  }

  /// Stream a single report by ID (for real-time updates)
  Stream<ReportData?> streamReportById(String reportId) {
    return _firestore.collection('reports').doc(reportId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return ReportData.fromFirestore(doc);
    });
  }

  /// Verify a report (admin action)
  Future<void> verifyReport(String reportId, String adminId) async {
    final docRef = _firestore.collection('reports').doc(reportId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Report not found');

        final report = ReportData.fromFirestore(snap);
        // If already verified, nothing to do
        if (report.isVerified) return;

        final ownerRef = _firestore.collection('users').doc(report.userId);

        tx.update(docRef, {
          'isVerified': true,
          'verifiedBy': adminId,
          'verifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Increment owner's verifiedReportsCount
        tx.update(ownerRef, {'verifiedReportsCount': FieldValue.increment(1)});
      });

      if (kDebugMode) {
        print('✅ Report $reportId verified by admin $adminId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error verifying report: $e');
      }
      rethrow;
    }
  }

  /// Resolve a report (admin action) - can only resolve verified reports
  Future<void> resolveReport(
    String reportId,
    String adminId, {
    String? note,
  }) async {
    try {
      // First check if report is verified
      final report = await getReportById(reportId);
      if (report == null) {
        throw Exception('Report not found');
      }
      if (!report.isVerified) {
        throw Exception(
          'Cannot resolve unverified report. Please verify first.',
        );
      }

      final updates = {
        'isResolved': true,
        'resolvedBy': adminId,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (note != null && note.isNotEmpty) {
        updates['note'] = note;
      }

      await _firestore.collection('reports').doc(reportId).update(updates);

      if (kDebugMode) {
        print('✅ Report $reportId resolved by admin $adminId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resolving report: $e');
      }
      rethrow;
    }
  }

  /// Flag a report (admin action)
  Future<void> flagReport(
    String reportId,
    String adminId, {
    String? note,
  }) async {
    final docRef = _firestore.collection('reports').doc(reportId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Report not found');

        final report = ReportData.fromFirestore(snap);
        // If already flagged, nothing to do
        if (report.isFlagged) return;

        final ownerRef = _firestore.collection('users').doc(report.userId);

        final updates = {
          'isFlagged': true,
          'flaggedBy': adminId,
          'flaggedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (note != null && note.isNotEmpty) {
          updates['note'] = note;
        }

        tx.update(docRef, updates);

        // Increment owner's flaggedReportsCount
        tx.update(ownerRef, {'flaggedReportsCount': FieldValue.increment(1)});
      });

      if (kDebugMode) {
        print('⚠️ Report $reportId flagged by admin $adminId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error flagging report: $e');
      }
      rethrow;
    }
  }

  /// Dismiss flag on a report (admin action)
  Future<void> dismissFlag(String reportId, String adminId) async {
    final docRef = _firestore.collection('reports').doc(reportId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Report not found');

        final report = ReportData.fromFirestore(snap);
        // If not flagged, nothing to do
        if (!report.isFlagged) return;

        final ownerRef = _firestore.collection('users').doc(report.userId);
        final ownerSnap = await tx.get(ownerRef);
        final currentFlagged =
            (ownerSnap.data()?['flaggedReportsCount'] as num?)?.toInt() ?? 0;
        final newFlagged = math.max(0, currentFlagged - 1);

        tx.update(docRef, {
          'isFlagged': false,
          'flagDismissedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write absolute non-negative value to avoid underflow
        tx.update(ownerRef, {'flaggedReportsCount': newFlagged});
      });

      if (kDebugMode) {
        print('✅ Flag dismissed on report $reportId by admin $adminId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error dismissing flag: $e');
      }
      rethrow;
    }
  }

  /// Dismiss verification (admin action) — undo a previous verify.
  Future<void> dismissVerification(String reportId, String adminId) async {
    final docRef = _firestore.collection('reports').doc(reportId);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Report not found');
        final report = ReportData.fromFirestore(snap);
        // If not verified, nothing to do
        if (!report.isVerified) return;

        final ownerRef = _firestore.collection('users').doc(report.userId);
        final ownerSnap = await tx.get(ownerRef);
        final currentVerified =
            (ownerSnap.data()?['verifiedReportsCount'] as num?)?.toInt() ?? 0;
        final newVerified = math.max(0, currentVerified - 1);

        // Remove verification fields and update timestamps; decrement owner's counter
        tx.update(docRef, {
          'isVerified': false,
          'verifiedBy': FieldValue.delete(),
          'verifiedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write absolute non-negative value to avoid underflow
        tx.update(ownerRef, {'verifiedReportsCount': newVerified});
      });

      if (kDebugMode) {
        print('✅ Verification dismissed on report $reportId by admin $adminId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error dismissing verification: $e');
      rethrow;
    }
  }

  /// Add or update note on report (admin action)
  Future<void> updateNote(String reportId, String note) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Note updated on report $reportId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating note: $e');
      }
      rethrow;
    }
  }

  /// Community confirm report (increment confirmCount)
  Future<void> confirmReport(String reportId, String userId) async {
    final docRef = _firestore.collection('reports').doc(reportId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Report not found');

        final report = ReportData.fromFirestore(snap);

        // Check if user can interact
        if (!report.canUserInteract(userId)) {
          throw Exception('Cannot interact with this report');
        }

        final ownerRef = _firestore.collection('users').doc(report.userId);

        final hadConfirmed = report.hasUserConfirmed(userId);
        final hadRefuted = report.hasUserRefuted(userId);

        final updates = <String, dynamic>{};

        if (hadConfirmed) {
          // retract confirmation
          updates['confirmCount'] = FieldValue.increment(-1);
          updates['confirmedBy'] = FieldValue.arrayRemove([userId]);

          tx.update(docRef, updates);
          // decrement owner's confirmReactionsCount
          tx.update(ownerRef, {
            'confirmReactionsCount': FieldValue.increment(-1),
          });
        } else {
          // add confirmation
          updates['confirmCount'] = FieldValue.increment(1);
          updates['confirmedBy'] = FieldValue.arrayUnion([userId]);

          if (hadRefuted) {
            updates['refuteCount'] = FieldValue.increment(-1);
            updates['refutedBy'] = FieldValue.arrayRemove([userId]);
          }

          tx.update(docRef, updates);
          // increment owner's confirmReactionsCount
          tx.update(ownerRef, {
            'confirmReactionsCount': FieldValue.increment(1),
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error confirming report: $e');
      }
      rethrow;
    }
  }

  /// Community refute report (increment refuteCount)
  Future<void> refuteReport(String reportId, String userId) async {
    final docRef = _firestore.collection('reports').doc(reportId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Report not found');

        final report = ReportData.fromFirestore(snap);

        // Check if user can interact
        if (!report.canUserInteract(userId)) {
          throw Exception('Cannot interact with this report');
        }

        final hadRefuted = report.hasUserRefuted(userId);
        final hadConfirmed = report.hasUserConfirmed(userId);

        final updates = <String, dynamic>{};

        if (hadRefuted) {
          // retract refute
          updates['refuteCount'] = FieldValue.increment(-1);
          updates['refutedBy'] = FieldValue.arrayRemove([userId]);

          tx.update(docRef, updates);
          // refute doesn't affect owner's confirm/verified/flagged counters
        } else {
          // add refute
          updates['refuteCount'] = FieldValue.increment(1);
          updates['refutedBy'] = FieldValue.arrayUnion([userId]);

          if (hadConfirmed) {
            updates['confirmCount'] = FieldValue.increment(-1);
            updates['confirmedBy'] = FieldValue.arrayRemove([userId]);
            // decrement owner's confirmReactionsCount because user moved from confirm -> refute
            final ownerRef = _firestore.collection('users').doc(report.userId);
            tx.update(ownerRef, {
              'confirmReactionsCount': FieldValue.increment(-1),
            });
          }

          tx.update(docRef, updates);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refuting report: $e');
      }
      rethrow;
    }
  }

  /// Increment view count for a report
  Future<void> incrementViewCount(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      // Silent fail for view count
      if (kDebugMode) {
        print('⚠️ Failed to increment view count: $e');
      }
    }
  }

  /// Soft delete a report
  Future<void> deleteReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Report $reportId deleted (soft delete)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting report: $e');
      }
      rethrow;
    }
  }

  /// Permanently delete a report (admin only)
  Future<void> permanentlyDeleteReport(String reportId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('reports').doc(reportId).delete();

      // Note: Media cleanup should be handled separately or via Cloud Functions
      if (kDebugMode) {
        print('✅ Report $reportId permanently deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error permanently deleting report: $e');
      }
      rethrow;
    }
  }

  /// Get cached download URL for media
  String? getCachedUrl(String mediaPath) {
    return _urlCache[mediaPath];
  }

  Future<String?> getDownloadUrl(String mediaPath) async {
    if (_urlCache.containsKey(mediaPath)) {
      return _urlCache[mediaPath];
    }
    try {
      final url = _storage.getPublicUrl(mediaPath);
      _urlCache[mediaPath] = url;
      return url;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching download URL: $e');
      }
      return null;
    }
  }

  /// Get reports statistics
  Future<Map<String, int>> getReportsStatistics() async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('isActive', isEqualTo: true)
          .get();

      int pending = 0;
      int verified = 0;
      int resolved = 0;
      int flagged = 0;

      for (var doc in snapshot.docs) {
        final report = ReportData.fromFirestore(doc);
        switch (report.status) {
          case ReportStatus.pending:
            pending++;
            break;
          case ReportStatus.verified:
            verified++;
            break;
          case ReportStatus.resolved:
            resolved++;
            break;
          case ReportStatus.flagged:
            flagged++;
            break;
        }
      }

      return {
        'total': snapshot.docs.length,
        'pending': pending,
        'verified': verified,
        'resolved': resolved,
        'flagged': flagged,
      };
    } catch (e) {
      if (kDebugMode) {
        if (e is FirebaseException) {
          debugPrint(
            '[Firestore][getReportsStatistics] FirebaseException code=${e.code} message=${e.message}',
          );
        } else {
          debugPrint('[Firestore][getReportsStatistics] Error: $e');
        }
        final msg = e.toString().toLowerCase();
        if (msg.contains('index')) {
          debugPrint(
            '[Firestore][getReportsStatistics] Consider adding indexes for reports queries used by statistics.',
          );
        }
        if (msg.contains('credentials_missing') ||
            msg.contains('unauthenticated')) {
          debugPrint(
            '[Firestore][getReportsStatistics] Auth issue detected: ensure proper credentials.',
          );
        }
      }
      return {};
    }
  }

  /// Clear URL cache
  void clearCache() {
    _urlCache.clear();
  }

  /// Stream only reports relevant for the map:
  /// active AND not resolved AND not flagged (covers pending + verified).
  Stream<List<ReportData>> getMapReports({
    String? barangayFilter,
    int limit = 300,
  }) {
    Query query = _firestore
        .collection('reports')
        .where('isActive', isEqualTo: true)
        .where('isResolved', isEqualTo: false)
        .where('isFlagged', isEqualTo: false);

    if (barangayFilter != null && barangayFilter.isNotEmpty) {
      query = query.where('barangay', isEqualTo: barangayFilter);
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            if (error is FirebaseException) {
              debugPrint(
                '[Firestore][getMapReports] FirebaseException code=${error.code} message=${error.message}',
              );
            } else {
              debugPrint('[Firestore][getMapReports] Stream error: $error');
            }
            final msg = error.toString().toLowerCase();
            if (msg.contains('index')) {
              debugPrint(
                '[Firestore][getMapReports] Index error: ensure composite index for isActive,isResolved,isFlagged + createdAt.',
              );
            }
            if (msg.contains('credentials_missing') ||
                msg.contains('unauthenticated')) {
              debugPrint(
                '[Firestore][getMapReports] Auth error: check Firebase credentials (firebase login / CLI project).',
              );
            }
          }
        }, test: (_) => true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReportData.fromFirestore(doc))
              .toList(),
        );
  }

  /// Reopen a resolved report (undo resolve). Keeps report verified state unchanged.
  Future<void> reopenReport(
    String reportId,
    String adminId, {
    String? note,
  }) async {
    final docRef = _firestore.collection('reports').doc(reportId);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Report not found');
        final report = ReportData.fromFirestore(snap);
        if (!report.isResolved) return;

        final updates = {
          'isResolved': false,
          'resolvedBy': FieldValue.delete(),
          'resolvedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (note != null && note.isNotEmpty) updates['note'] = note;

        tx.update(docRef, updates);
      });

      if (kDebugMode) {
        print('✅ Report $reportId reopened by admin $adminId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error reopening report: $e');
      rethrow;
    }
  }
}

class _CompressArgs {
  final String path;
  final int quality;
  final int maxWidth;
  _CompressArgs({
    required this.path,
    required this.quality,
    required this.maxWidth,
  });
}

Uint8List? _compressImageIsolate(_CompressArgs args) {
  try {
    final bytes = File(args.path).readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final resized = img.copyResize(image, width: args.maxWidth);
    return Uint8List.fromList(img.encodeJpg(resized, quality: args.quality));
  } catch (_) {
    return null;
  }
}

Uint8List? _readFileAsBytesIsolate(String path) {
  try {
    return File(path).readAsBytesSync();
  } catch (_) {
    return null;
  }
}

