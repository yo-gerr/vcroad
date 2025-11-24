import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/utils/dialog/reminder.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_scope.dart';
import 'package:vcroad_v2/shared/utils/routing/role_config.dart';
import 'package:vcroad_v2/shared/utils/routing/role_navigation_shell.dart';
import 'package:vcroad_v2/shared/utils/dialog/tutorial.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad_v2/shared/models/advisory.dart';
import 'package:vcroad_v2/shared/utils/dialog/advisory_alert.dart';

class AppScreen extends StatefulWidget {
  final UserRole role;
  final UserDetails? userDetails;

  const AppScreen({super.key, required this.role, this.userDetails});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  int _selectedIndex = 0;
  final PageStorageBucket _bucket = PageStorageBucket();

  int _pendingCount = 0;
  StreamSubscription<QuerySnapshot>? _pendingSub;

  // --- New-advisory alert state ---
  StreamSubscription<QuerySnapshot>? _newAdvSub;
  final Set<String> _shownIds = <String>{};
  final List<Advisory> _alertQueue = <Advisory>[];
  bool _showingAlert = false;
  DateTime? _baselineCreatedAt; // don’t alert older docs
  DateTime? _muteUntil;

  @override
  void initState() {
    super.initState();
    // Show tutorial (first-time) then reminder on every app open.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Only show tutorial/reminder for regular users (not admins/sysadmin).
      final role = widget.userDetails?.role;
      if (role == UserRole.user) {
        await showTutorialIfFirstTime(
          context,
          userId: widget.userDetails?.userId,
        );
        if (!mounted) return;
        // After tutorial completes (or immediately if already seen), show reminder.
        await showReminderOnLaunch(context);
      }
    });

    // If this session is admin (local admin) or sysadmin, subscribe to pending reports count.
    if (widget.role == UserRole.admin || widget.role == UserRole.sysadmin) {
      final bool isSysAdmin = widget.role == UserRole.sysadmin;

      // Determine barangay for local admin. Adjust field access to match your UserDetails model.
      final String? adminBarangay = isSysAdmin
          ? null
          : widget.userDetails?.barangay?.name;

      // If admin but no barangay available, don't subscribe (avoid wrong data).
      if (!isSysAdmin && (adminBarangay == null || adminBarangay.isEmpty)) {
        if (mounted) setState(() => _pendingCount = 0);
      } else {
        Query q = FirebaseFirestore.instance
            .collection('reports')
            .where('isActive', isEqualTo: true)
            .where('isVerified', isEqualTo: false)
            .where('isResolved', isEqualTo: false)
            .where('isFlagged', isEqualTo: false);

        // Scope to barangay for non-sysadmin admins
        if (!isSysAdmin) {
          q = q.where('barangay', isEqualTo: adminBarangay);
        }

        // Real-time count update (subscribe)
        _pendingSub = q.snapshots().listen(
          (snap) {
            if (!mounted) return;
            setState(() => _pendingCount = snap.size);
          },
          onError: (e) {
            if (kDebugMode)
              debugPrint('[AppScreen] pending reports stream error: $e');
          },
        );

        // OPTIONAL: if you prefer a single fast count instead of live updates
        // you can run an aggregate (if supported):
        // try {
        //   final agg = await q.count().get();
        //   if (mounted) setState(() => _pendingCount = agg.count);
        // } catch (_) { /* fallback to snapshots above */ }
      }
    }

    // Start new-advisory alerts for regular users
    if (widget.role == UserRole.user) {
      _restoreAlertPrefs().then((_) => _listenForNewAdvisories());
    }
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _newAdvSub?.cancel(); // <-- added
    super.dispose();
  }

  Future<void> _restoreAlertPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final muteStr = prefs.getString('advisory_alert_muted_until');
    if (muteStr != null) {
      _muteUntil = DateTime.tryParse(muteStr);
    }
    final baselineStr = prefs.getString('advisory_alert_baseline_created_at');
    if (baselineStr != null) {
      _baselineCreatedAt = DateTime.tryParse(baselineStr);
    }
  }

  Future<void> _saveMuteUntil(DateTime until) async {
    _muteUntil = until;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'advisory_alert_muted_until',
      until.toIso8601String(),
    );
  }

  Future<void> _saveBaseline(DateTime createdAt) async {
    _baselineCreatedAt = createdAt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'advisory_alert_baseline_created_at',
      createdAt.toIso8601String(),
    );
  }

  void _listenForNewAdvisories() {
    // active + scheduled only, newest first
    final q = FirebaseFirestore.instance
        .collection('advisories')
        .where('status', whereIn: ['active', 'scheduled'])
        .orderBy('createdAt', descending: true)
        .limit(20);

    bool firstSnapshotHandled = false;

    _newAdvSub = q.snapshots().listen(
      (snap) async {
        if (!mounted) return;

        // On the very first snapshot, set the baseline to the latest createdAt so
        // we don’t alert for historical data.
        if (!firstSnapshotHandled) {
          firstSnapshotHandled = true;
          if (snap.docs.isNotEmpty) {
            final ts = snap.docs.first.data()['createdAt'];
            if (ts is Timestamp) {
              await _saveBaseline(ts.toDate());
            }
          }
          return;
        }

        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;

          final data = change.doc.data();
          if (data == null) continue;

          // createdAt guard
          final createdAtRaw = data['createdAt'];
          final createdAt = createdAtRaw is Timestamp
              ? createdAtRaw.toDate()
              : (createdAtRaw is String
                    ? DateTime.tryParse(createdAtRaw)
                    : null);

          if (createdAt == null) continue;
          if (_baselineCreatedAt != null &&
              !createdAt.isAfter(_baselineCreatedAt!)) {
            continue; // older than baseline
          }

          // mute guard
          if (_muteUntil != null && DateTime.now().isBefore(_muteUntil!)) {
            continue;
          }

          // dedupe guard
          final id = change.doc.id;
          if (_shownIds.contains(id)) continue;

          // avoid self-notification if creator matches this user
          final createdBy = (data['createdBy'] as String?) ?? '';
          final currentEmail = widget.userDetails?.email ?? '';
          if (createdBy.isNotEmpty &&
              currentEmail.isNotEmpty &&
              createdBy == currentEmail) {
            continue;
          }

          // map to model
          final advisory = Advisory.fromJson(
            data as Map<String, dynamic>,
            advisoryId: id,
          );
          _alertQueue.add(advisory);
        }

        _showNextAlertIfIdle();
      },
      onError: (e) {
        if (kDebugMode) {
          debugPrint('[AppScreen] new-advisory stream error: $e');
        }
      },
    );
  }

  void _showNextAlertIfIdle() {
    if (!mounted || _showingAlert) return;
    if (_alertQueue.isEmpty) return;

    final advisory = _alertQueue.removeAt(0);
    _showingAlert = true;
    _shownIds.add(advisory.advisoryId);

    AdvisoryAlert.show(
      context: context,
      advisory: advisory,
      onView: () {
        // Jump to Advisory tab when user taps View
        setState(() => _selectedIndex = 2);
      },
      onMuteToday: () async {
        // mute until end-of-day
        final now = DateTime.now();
        final until = DateTime(now.year, now.month, now.day, 23, 59, 59);
        await _saveMuteUntil(until);
      },
    ).whenComplete(() {
      _showingAlert = false;
      // After closing, show any queued alerts
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showNextAlertIfIdle(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      child: Builder(
        builder: (context) {
          final config = RoleConfig.getConfig(widget.role);
          final isWideLayout = context.isTablet || context.isDesktop;

          return RoleNavigationShell(
            config: config,
            selectedIndex: _selectedIndex,
            onItemSelected: _onItemSelected,
            bucket: _bucket,
            hasWideLayout: isWideLayout,
            // only pass badge count to shell; shell will render it on index 1
            reportsBadgeCount: widget.role == UserRole.admin
                ? _pendingCount
                : null,
          );
        },
      ),
    );
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
