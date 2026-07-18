import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/repositories/report.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/presentation/providers/report.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/presentation/shared/widgets/image/preview.dart';
import 'package:vcroad/core/utils/map/interaction_controller.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/data/repositories/marker.dart'; // added import
import 'package:vcroad/core/utils/format/date_time.dart';
import 'package:vcroad/data/repositories/account.dart';
import 'package:vcroad/core/utils/format/text.dart';
import 'package:vcroad/presentation/shared/dialogs/confirmation.dart';
import 'package:vcroad/presentation/shared/widgets/video/preview.dart';

class ReportDetailsDialog extends StatefulWidget {
  final String reportId;
  const ReportDetailsDialog({super.key, required this.reportId});

  static Future<void> show(BuildContext context, String reportId) async {
    final controller = MapInteractionController.instance;
    controller.acquire();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => ReportDetailsDialog(reportId: reportId),
      );
    } finally {
      controller.release();
    }
  }

  @override
  State<ReportDetailsDialog> createState() => _ReportDetailsDialogState();
}

class _ReportDetailsDialogState extends State<ReportDetailsDialog> {
  bool _viewCountIncremented = false;

  // Cache for resolved user display names (userId -> fullName or fallback)
  final Map<String, String> _userNameCache = {};

  // Inline feedback (like CreateLessonDialog)
  String? _inlineMessage;
  Color? _inlineMessageColor;
  Timer? _inlineMessageTimer;

  void _showInlineMessage(
    String message, {
    Color color = Colors.red,
    Duration duration = const Duration(seconds: 4),
  }) {
    _inlineMessageTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _inlineMessage = message;
      _inlineMessageColor = color;
    });
    _inlineMessageTimer = Timer(duration, () {
      if (mounted) setState(() => _inlineMessage = null);
    });
  }

  // Loading flags for admin actions to provide immediate UI feedback and avoid duplicate calls.
  bool _isVerifying = false;
  bool _isResolving = false;
  bool _isFlagging = false;

  // category color is obtained from ReportCategory.color (centralized in model)
  // ----- Admin actions (improved UI/UX) -----
  Widget _buildAdminActions(ReportData r) {
    final info = context.responsive;
    final userProv = context.watch<UserProvider>();
    final user = userProv.user;
    if (user == null) return const SizedBox.shrink();

    // Role flags
    final bool isAdmin =
        (userProv.isAdmin == true) && (userProv.isSysAdmin == false);
    final bool isSysAdmin = (userProv.isSysAdmin == true);
    // If neither admin nor sysadmin, hide actions
    if (!isAdmin && !isSysAdmin) return const SizedBox.shrink();

    // Buttons behave as toggles:
    // - Verify button: Verify (if not verified) or Dismiss Verification (if verified)
    // - Resolve button: Resolve (if verified & not resolved) or Reopen (if resolved)
    final bool verifyActionInProgress = _isVerifying;
    final bool resolveActionInProgress = _isResolving;
    // UI guard: only allow resolve action if report is verified, not resolved and not flagged.
    final canVerifyAction = !r.isFlagged && !verifyActionInProgress;
    final canResolveAction =
        r.isVerified &&
        !r.isResolved &&
        !r.isFlagged &&
        !resolveActionInProgress;

    final double btnHeight = info.scale(44);

    Widget button({
      required String tooltip,
      required Color color,
      required Widget child,
      required VoidCallback? onPressed,
      required Color disabledColor,
      required String semanticsLabel,
    }) {
      final enabled = onPressed != null;
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: semanticsLabel,
          child: SizedBox(
            height: btnHeight,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled ? color : disabledColor,
                padding: EdgeInsets.symmetric(horizontal: info.scale(12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: enabled ? 2 : 0,
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    Widget iconOrSpinner(bool loading, IconData icon, Color iconColor) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: loading
            ? SizedBox(
                width: info.scale(18),
                height: info.scale(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: info.scale(18), color: Colors.white),
      );
    }

    // SysAdmin-only: allow dismissing a flagged report (read-only otherwise)
    if (isSysAdmin && !isAdmin) {
      if (!r.isFlagged) return const SizedBox.shrink();
      // show a single dismiss-button for flagged reports
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: btnHeight,
              child: ElevatedButton.icon(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _isFlagging
                      ? SizedBox(
                          width: info.scale(18),
                          height: info.scale(18),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.flag_circle,
                          size: info.scale(18),
                          color: Colors.white,
                        ),
                ),
                onPressed: !_isFlagging
                    ? () async {
                        final ok =
                            await showDialog<bool>(
                              context: context,
                              builder: (ctx) => const ConfirmationDialog(
                                title: 'Dismiss flag?',
                                message:
                                    'Remove flagged status from this report?',
                                confirmText: 'Dismiss',
                                cancelText: 'Cancel',
                              ),
                            ) ??
                            false;
                        if (!ok) return;
                        setState(() => _isFlagging = true);
                        try {
                          await ReportService.instance.dismissFlag(
                            r.reportId,
                            user.userId,
                          );
                          if (!mounted) return;
                          _showInlineMessage(
                            'Flag dismissed',
                            color: Colors.green,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          _showInlineMessage(
                            'Dismiss failed: $e',
                            color: Colors.red,
                          );
                        } finally {
                          if (mounted) setState(() => _isFlagging = false);
                        }
                      }
                    : null,
                label: Text(
                  'Dismiss Flag',
                  style: TextStyle(
                    fontSize: info.scaleFont(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
          ),
        ],
      );
    }

    // Default admin actions (for Admin role only)
    return Row(
      children: [
        // Verify (primary)
        Expanded(
          child: button(
            tooltip: r.isVerified ? 'Dismiss verification' : 'Verify report',
            color: r.isVerified ? Colors.blueGrey : Colors.blue,
            disabledColor: Colors.grey.shade300,
            semanticsLabel: r.isVerified
                ? 'Dismiss verification'
                : 'Verify report',
            onPressed: canVerifyAction
                ? () async {
                    setState(() => _isVerifying = true);
                    try {
                      if (!r.isVerified) {
                        await _adminVerify(r);
                      } else {
                        final ok =
                            await showDialog<bool>(
                              context: context,
                              builder: (ctx) => const ConfirmationDialog(
                                title: 'Dismiss verification?',
                                message:
                                    'Remove verification from this report? This will decrement the submitter\'s verified count.',
                                confirmText: 'Dismiss',
                                cancelText: 'Cancel',
                              ),
                            ) ??
                            false;
                        if (ok) {
                          await ReportService.instance.dismissVerification(
                            r.reportId,
                            user.userId,
                          );
                          if (!mounted) return;
                          _showInlineMessage(
                            'Verification dismissed',
                            color: Colors.green,
                          );
                        }
                      }
                    } catch (e) {
                      if (!mounted) return;
                      _showInlineMessage(
                        'Verify action failed: $e',
                        color: Colors.red,
                      );
                    } finally {
                      if (mounted) setState(() => _isVerifying = false);
                    }
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconOrSpinner(_isVerifying, Icons.verified, Colors.white),
                SizedBox(width: info.scale(8)),
                Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: info.scaleFont(14),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: info.scale(10)),
        // Resolve (secondary)
        Expanded(
          child: button(
            tooltip: r.isResolved ? 'Reopen report' : 'Resolve report',
            color: r.isResolved ? Colors.green.shade700 : Colors.green,
            disabledColor: Colors.grey.shade300,
            semanticsLabel: r.isResolved ? 'Reopen report' : 'Resolve report',
            onPressed: canResolveAction
                ? () async {
                    setState(() => _isResolving = true);
                    try {
                      if (!r.isResolved) {
                        final ok =
                            await showDialog<bool>(
                              context: context,
                              builder: (ctx) => const ConfirmationDialog(
                                title: 'Resolve report?',
                                message:
                                    'Mark this report as resolved? This action can be reversed.',
                                confirmText: 'Resolve',
                                cancelText: 'Cancel',
                              ),
                            ) ??
                            false;
                        if (!ok) return;
                        await _adminResolve(r);
                      } else {
                        final ok =
                            await showDialog<bool>(
                              context: context,
                              builder: (ctx) => const ConfirmationDialog(
                                title: 'Reopen report?',
                                message:
                                    'Reopen this resolved report? This will make it active again.',
                                confirmText: 'Reopen',
                                cancelText: 'Cancel',
                              ),
                            ) ??
                            false;
                        if (ok) {
                          await ReportService.instance.reopenReport(
                            r.reportId,
                            user.userId,
                          );
                          if (!mounted) return;
                          _showInlineMessage(
                            'Report reopened',
                            color: Colors.green,
                          );
                        }
                      }
                    } catch (e) {
                      if (!mounted) return;
                      _showInlineMessage(
                        'Resolve action failed: $e',
                        color: Colors.red,
                      );
                    } finally {
                      if (mounted) setState(() => _isResolving = false);
                    }
                  }
                : () {
                    _showInlineMessage(
                      'Report must be verified before resolving',
                      color: Colors.orange,
                    );
                  },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconOrSpinner(_isResolving, Icons.check_circle, Colors.white),
                SizedBox(width: info.scale(8)),
                Text(
                  'Resolve',
                  style: TextStyle(
                    fontSize: info.scaleFont(14),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: info.scale(10)),
        // Flag / Unflag (destructive)
        Expanded(
          child: Tooltip(
            message: r.isFlagged
                ? 'Remove flag'
                : 'Flag report as inappropriate',
            child: Semantics(
              button: true,
              label: r.isFlagged ? 'Unflag report' : 'Flag report',
              child: SizedBox(
                height: btnHeight,
                child: ElevatedButton(
                  onPressed: !(_isFlagging)
                      ? () async {
                          final confirmMessage = r.isFlagged
                              ? 'Remove flag from this report?'
                              : 'Flag this report as inappropriate?';
                          final ok =
                              await showDialog<bool>(
                                context: context,
                                builder: (ctx) => ConfirmationDialog(
                                  title: r.isFlagged
                                      ? 'Remove flag'
                                      : 'Flag report',
                                  message: confirmMessage,
                                  confirmText: r.isFlagged ? 'Unflag' : 'Flag',
                                  cancelText: 'Cancel',
                                ),
                              ) ??
                              false;
                          if (!ok) return;
                          setState(() => _isFlagging = true);
                          try {
                            await _adminToggleFlag(r);
                          } finally {
                            if (mounted) setState(() => _isFlagging = false);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: r.isFlagged
                        ? Colors.orange
                        : Colors.redAccent,
                    padding: EdgeInsets.symmetric(horizontal: info.scale(12)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: (_isFlagging ? 0 : 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      iconOrSpinner(
                        _isFlagging,
                        r.isFlagged ? Icons.flag_circle : Icons.flag,
                        Colors.white,
                      ),
                      SizedBox(width: info.scale(8)),
                      Text(
                        r.isFlagged ? 'Unflag' : 'Flag',
                        style: TextStyle(
                          fontSize: info.scaleFont(14),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _adminVerify(ReportData r) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    try {
      await ReportService.instance.verifyReport(r.reportId, user.userId);
      if (!mounted) return;
      _showInlineMessage('Report verified', color: Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showInlineMessage('Verify failed: $e', color: Colors.red);
    }
  }

  Future<void> _adminResolve(ReportData r) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    try {
      await ReportService.instance.resolveReport(r.reportId, user.userId);
      if (!mounted) return;
      _showInlineMessage('Report resolved', color: Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showInlineMessage('Resolve failed: $e', color: Colors.red);
    }
  }

  Future<void> _adminToggleFlag(ReportData r) async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    try {
      if (r.isFlagged) {
        await ReportService.instance.dismissFlag(r.reportId, user.userId);
        if (!mounted) return;
        _showInlineMessage('Flag dismissed', color: Colors.green);
      } else {
        await ReportService.instance.flagReport(r.reportId, user.userId);
        if (!mounted) return;
        _showInlineMessage('Report flagged', color: Colors.green);
      }
    } catch (e) {
      if (!mounted) return;
      _showInlineMessage('Flag action failed: $e', color: Colors.red);
    }
  }
  // ----- end admin actions -----

  @override
  void dispose() {
    _inlineMessageTimer?.cancel();
    // video controller removed
    super.dispose();
  }

  // Increment view count only once per dialog open
  void _maybeIncrementViewCount(ReportData r) {
    if (_viewCountIncremented) return;
    _viewCountIncremented = true;
    unawaited(ReportService.instance.incrementViewCount(r.reportId));
  }

  // Resolve and cache display names for audit userIds (non-blocking).
  Future<void> _ensureAuditUserNames(ReportData r) async {
    final ids = <String>{};
    if (r.verifiedBy?.isNotEmpty == true) ids.add(r.verifiedBy!);
    if (r.resolvedBy?.isNotEmpty == true) ids.add(r.resolvedBy!);
    if (r.flaggedBy?.isNotEmpty == true) ids.add(r.flaggedBy!);

    // Determine which ids are missing from cache
    final missing = ids.where((id) => !_userNameCache.containsKey(id)).toList();
    if (missing.isEmpty) return;

    final Map<String, String> fetched = {};
    for (final id in missing) {
      try {
        final user = await AccountService.instance.getUserById(id);
        // Store a title-cased display name for readability
        final rawName = user?.fullName ?? id;
        fetched[id] = TextFormat.titleCaseOrNull(rawName) ?? rawName;
      } catch (_) {
        fetched[id] = id;
      }
    }
    if (!mounted) return;
    setState(() => _userNameCache.addAll(fetched));
  }

  // Audit / submitter section visible to admin/sysadmin (non-user) roles.
  Widget _buildAuditSection(ReportData r, dynamic responsive) {
    final submitterName = TextFormat.titleCaseOrNull(r.fullName) ?? '—';
    final submitterContact = <String>[
      if (r.email.isNotEmpty) r.email,
      if (r.phoneNumber.isNotEmpty) r.phoneNumber,
    ].join(' • ');

    Widget infoRow(IconData icon, String label, String value) {
      return Padding(
        padding: EdgeInsets.only(bottom: responsive.scale(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: responsive.scale(18), color: Colors.grey.shade700),
            SizedBox(width: responsive.scale(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: responsive.scaleFont(12),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: responsive.scale(4)),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: responsive.scaleFont(13),
                      color: Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Audit entries (display resolved names when available)
    String displayName(String? id) {
      if (id == null || id.isEmpty) return '—';
      // cached names are already title-cased on fetch; fall back to id
      return _userNameCache[id] ?? id;
    }

    final verifiedBy = displayName(r.verifiedBy);
    final resolvedBy = displayName(r.resolvedBy);
    final flaggedBy = displayName(r.flaggedBy);
    final flaggedAt = r.flaggedAt == null
        ? '—'
        : DateFormatUtils.formatFriendly(r.flaggedAt!);
    final verifiedAt = r.verifiedAt == null
        ? '—'
        : DateFormatUtils.formatFriendly(r.verifiedAt!);
    final resolvedAt = r.resolvedAt == null
        ? '—'
        : DateFormatUtils.formatFriendly(r.resolvedAt!);
    final updatedAt = DateFormatUtils.formatFriendly(
      (r.updatedAt ?? r.createdAt),
    );

    return _buildSection(
      responsive,
      'Audit & Submitter',
      Icons.person,
      Colors.purple,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          infoRow(Icons.person_outline, 'Submitted by', submitterName),
          if (submitterContact.isNotEmpty)
            infoRow(Icons.contact_mail, 'Contact', submitterContact),
          infoRow(
            Icons.calendar_today,
            'Submitted at',
            DateFormatUtils.formatFriendly(r.createdAt),
          ),
          const Divider(),
          infoRow(Icons.verified, 'Verified', '$verifiedBy • $verifiedAt'),
          infoRow(Icons.check_circle, 'Resolved', '$resolvedBy • $resolvedAt'),
          infoRow(Icons.flag, 'Flagged', '$flaggedBy • $flaggedAt'),
          infoRow(Icons.update, 'Last updated', updatedAt),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: info.scale(16),
        vertical: info.scale(24),
      ),
      child: ConstrainedBox(
        // Match Advisory dialog sizing and feel for consistency
        constraints: BoxConstraints(
          maxWidth: info.isDesktop ? 800 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: StreamBuilder<ReportData?>(
            stream: ReportService.instance.streamReportById(widget.reportId),
            builder: (context, snap) {
              // Prefer realtime snapshot, fallback to provider cached list if available for instant render.
              final providerCached = context
                  .select<ReportProvider, ReportData?>((p) {
                    try {
                      return p.allReports.firstWhere(
                        (r) => r.reportId == widget.reportId,
                      );
                    } catch (_) {
                      return null;
                    }
                  });

              final data = snap.data ?? providerCached;
              if (data == null) {
                // No spinner — render an empty dialog content until data is present
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(context, info),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(info.scale(20)),
                        child: Text(
                          'Report not available',
                          style: TextStyle(fontSize: info.scaleFont(14)),
                        ),
                      ),
                    ),
                    _buildFooter(context, info),
                  ],
                );
              }

              // Ensure view count and video init run once when we have data
              _maybeIncrementViewCount(data);
              // video removed — no init call

              // role provider for conditional UI (audit / submitter info visible to non-user roles)
              final userProv = context.watch<UserProvider>();
              // Resolve audit user names in background (non-blocking, cached)
              unawaited(_ensureAuditUserNames(data));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, info, report: data),
                  if (_inlineMessage != null)
                    Container(
                      width: double.infinity,
                      color:
                          _inlineMessageColor?.withValues(alpha: 0.12) ??
                          Colors.red.withValues(alpha: 0.12),
                      padding: EdgeInsets.symmetric(
                        horizontal: info.scale(16),
                        vertical: info.scale(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: _inlineMessageColor ?? Colors.red,
                            size: info.scale(18),
                          ),
                          SizedBox(width: info.scale(8)),
                          Expanded(
                            child: Text(
                              _inlineMessage!,
                              style: TextStyle(
                                color: _inlineMessageColor ?? Colors.red,
                                fontSize: info.scaleFont(13),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: info.scale(18)),
                            color: _inlineMessageColor ?? Colors.red,
                            onPressed: () {
                              _inlineMessageTimer?.cancel();
                              if (mounted) {
                                setState(() => _inlineMessage = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(info.scale(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Media: photo or video. Video opens a dedicated preview/player.
                          if (data.mediaType == MediaType.photo &&
                              ((data.mediaUrl?.isNotEmpty == true) ||
                                  data.mediaPath.isNotEmpty)) ...[
                            _buildImageSection(
                              context,
                              info,
                              data.mediaUrl?.isNotEmpty == true
                                  ? data.mediaUrl!
                                  : data.mediaPath,
                            ),
                            SizedBox(height: info.scale(12)),
                          ] else if (data.mediaType == MediaType.video &&
                              ((data.mediaUrl?.isNotEmpty == true) ||
                                  data.mediaPath.isNotEmpty)) ...[
                            _buildVideoSection(
                              context,
                              info,
                              data.mediaUrl?.isNotEmpty == true
                                  ? data.mediaUrl!
                                  : data.mediaPath,
                            ),
                            SizedBox(height: info.scale(12)),
                          ],
                          _buildStatusBadge(data, info),
                          SizedBox(height: info.scale(12)),
                          _buildSection(
                            info,
                            'Location',
                            Icons.location_on,
                            Colors.red,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                  info,
                                  'Barangay',
                                  data.barangay,
                                  Icons.place,
                                ),
                                SizedBox(height: info.scale(8)),
                                _buildInfoRow(
                                  info,
                                  'Address',
                                  data.address,
                                  Icons.map,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: info.scale(12)),
                          _buildSection(
                            info,
                            'Details',
                            Icons.description,
                            Colors.blue,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                  info,
                                  'Category',
                                  data.category.label,
                                  Icons.label,
                                ),
                                if (data.note != null &&
                                    data.note!.isNotEmpty) ...[
                                  SizedBox(height: info.scale(8)),
                                  Text(
                                    data.note!,
                                    style: TextStyle(
                                      fontSize: info.scaleFont(14),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Show submitter + audit details for admin/sysadmin (non-user) roles.
                          if (!(userProv.isUser))
                            SizedBox(height: info.scale(12)),
                          if (!(userProv.isUser))
                            _buildAuditSection(data, info),
                          SizedBox(height: info.scale(12)),
                          _buildMapSection(context, data, info),
                          SizedBox(height: info.scale(12)),
                          Text(
                            'Interaction',
                            style: TextStyle(
                              fontSize: info.scaleFont(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: info.scale(6)),
                          // Interaction controls for regular users; admins/sysadmins see a read-only summary
                          Builder(
                            builder: (ctx) {
                              final userProv = ctx.watch<UserProvider>();
                              if (userProv.isUser) {
                                return _InteractionRow(report: data);
                              }
                              // Non-user (admin/sysadmin) summary view
                              return _buildAdminInteractionSummary(data, info);
                            },
                          ),
                          SizedBox(height: info.scale(12)),
                          _buildAdminActions(data),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(context, info),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic responsive, {
    ReportData? report,
  }) {
    final category = report?.category;
    final color = category?.color ?? const Color(0xFF001278);
    return Container(
      padding: EdgeInsets.all(responsive.scale(16)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: responsive.scale(48),
            height: responsive.scale(48),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: category?.asset != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(category!.asset, fit: BoxFit.contain),
                  )
                : Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: responsive.scale(28),
                  ),
          ),
          SizedBox(width: responsive.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report?.category.label ?? 'Report',
                  style: TextStyle(
                    fontSize: responsive.scaleFont(18),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'Report Details',
                  style: TextStyle(
                    fontSize: responsive.scaleFont(12),
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// Image wrapped inside a styled section so it expands full width like other sections.
  Widget _buildImageSection(
    BuildContext context,
    dynamic responsive,
    String mediaSrc,
  ) {
    final maxHeight = (responsive.scale(180)).clamp(80.0, 420.0) as double;
    final heroTag = 'report_preview_${identityHashCode(mediaSrc)}';

    return _buildSection(
      responsive,
      'Image',
      Icons.image,
      Colors.grey,
      RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: double.infinity,
            height: maxHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      final overlayCtx =
                          Navigator.of(context).overlay?.context ?? context;
                      final provider = mediaSrc.startsWith('http')
                          ? NetworkImage(mediaSrc)
                          : FileImage(File(mediaSrc));
                      await precacheImage(
                        provider as ImageProvider<Object>,
                        overlayCtx,
                      );
                    } catch (_) {}
                    if (!context.mounted) return;
                    await showImagePreviewDialog(context, mediaSrc);
                  },
                  child: Hero(
                    tag: heroTag,
                    child: Builder(
                      builder: (_) {
                        if (mediaSrc.startsWith('http')) {
                          return Image.network(
                            mediaSrc,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: maxHeight,
                          );
                        } else {
                          return Image.file(
                            File(mediaSrc),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: maxHeight,
                          );
                        }
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        try {
                          final overlayCtx =
                              Navigator.of(context).overlay?.context ?? context;
                          final provider = mediaSrc.startsWith('http')
                              ? NetworkImage(mediaSrc)
                              : FileImage(File(mediaSrc));
                          await precacheImage(
                            provider as ImageProvider<Object>,
                            overlayCtx,
                          );
                        } catch (_) {}
                        if (!context.mounted) return;
                        await showImagePreviewDialog(context, mediaSrc);
                      },
                      child: Padding(
                        padding: EdgeInsets.all(responsive.scale(8)),
                        child: Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: responsive.scale(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Video placeholder that opens full player on tap.
  Widget _buildVideoSection(
    BuildContext context,
    dynamic responsive,
    String mediaSrc,
  ) {
    final double height = responsive.scale(180).clamp(120.0, 420.0) as double;

    return _buildSection(
      responsive,
      'Video',
      Icons.videocam,
      Colors.grey,
      GestureDetector(
        onTap: () async {
          if (!context.mounted) return;
          // Open the lightweight, on-demand video preview dialog
          await showVideoPreviewDialog(context, mediaSrc);
        },
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: height,
              width: double.infinity,
              color: Colors.grey.shade100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Simple visual affordance: play icon + small hint
                  Icon(
                    Icons.videocam_outlined,
                    size: responsive.scale(36),
                    color: Colors.grey.shade500,
                  ),
                  Positioned(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(responsive.scale(10)),
                        child: Icon(
                          Icons.play_arrow,
                          size: responsive.scale(28),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(responsive.scale(8)),
                        child: InkWell(
                          onTap: () async {
                            if (!context.mounted) return;
                            await showVideoPreviewDialog(context, mediaSrc);
                          },
                          customBorder: const CircleBorder(),
                          child: Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: responsive.scale(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildStatusBadge(ReportData r, dynamic responsive) {
  final Color color = r.statusColor;
  final String label = r.statusLabel;

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: responsive.scale(12),
      vertical: responsive.scale(8),
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info, size: responsive.scale(16), color: color),
        SizedBox(width: responsive.scale(8)),
        Text(
          label,
          style: TextStyle(
            fontSize: responsive.scaleFont(13),
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _buildMapSection(
  BuildContext context,
  ReportData r,
  dynamic responsive,
) {
  return _buildSection(
    responsive,
    'Map View',
    Icons.map,
    Colors.teal,
    SizedBox(
      height: responsive.scale(220),
      child: RepaintBoundary(
        child: FutureBuilder<Marker>(
          future: MarkerService.instance.getReportMarkerFor(
            id: r.reportId,
            position: r.location,
            category: r.category,
            title: r.category.label,
            snippet: r.address.isNotEmpty ? r.address : null,
            context: context,
            logicalSize: responsive.isDesktop ? 52.0 : 44.0,
          ),
          builder: (ctx, snap) {
            // Fast fallback: use cached marker or hue default while loading / on error.
            final Marker fallback = MarkerService.instance
                .buildReportMarkerFromCache(
                  id: r.reportId,
                  position: r.location,
                  category: r.category,
                  title: r.category.label,
                  snippet: r.address.isNotEmpty ? r.address : null,
                );
            final marker = snap.data ?? fallback;

            return FlutterMap(
              options: MapOptions(
                initialCenter: r.location,
                initialZoom: 17,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.vcroad.app',
                ),
                MarkerLayer(markers: [marker], rotate: true),
                PolylineLayer(
                  polylines: BarangayService().isLoaded
                      ? BarangayService().generateBarangayPolylines(
                          color: Colors.blue.withValues(alpha: 0.4),
                        )
                      : [],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

Widget _buildSection(
  dynamic responsive,
  String title,
  IconData icon,
  Color color,
  Widget content,
) {
  return Container(
    padding: EdgeInsets.all(responsive.scale(16)),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(responsive.scale(8)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: responsive.scale(20)),
            ),
            SizedBox(width: responsive.scale(12)),
            Text(
              title,
              style: TextStyle(
                fontSize: responsive.scaleFont(16),
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        SizedBox(height: responsive.scale(12)),
        content,
      ],
    ),
  );
}

Widget _buildInfoRow(
  dynamic responsive,
  String label,
  String value,
  IconData icon,
) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: responsive.scale(16), color: Colors.grey.shade600),
      SizedBox(width: responsive.scale(8)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.scaleFont(12),
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: responsive.scale(2)),
            Text(
              value,
              style: TextStyle(
                fontSize: responsive.scaleFont(14),
                color: Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildFooter(BuildContext context, dynamic responsive) {
  return Container(
    padding: EdgeInsets.all(responsive.scale(16)),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(14),
        bottomRight: Radius.circular(14),
      ),
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
            label: Text(
              'Close',
              style: TextStyle(fontSize: responsive.scaleFont(14)),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: responsive.scale(12)),
            ),
          ),
        ),
      ],
    ),
  );
}

// Shows confirm/refute totals for admins and sysadmins (read-only).
Widget _buildAdminInteractionSummary(ReportData r, dynamic responsive) {
  final confirm = r.confirmCount;
  final refute = r.refuteCount;

  return Row(
    children: [
      Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.scale(12),
            vertical: responsive.scale(10),
          ),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.thumb_up,
                color: Colors.green,
                size: responsive.scale(18),
              ),
              SizedBox(width: responsive.scale(8)),
              Text(
                '$confirm confirmed',
                style: TextStyle(
                  fontSize: responsive.scaleFont(13),
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(width: responsive.scale(12)),
      Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.scale(12),
            vertical: responsive.scale(10),
          ),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.thumb_down,
                color: Colors.red,
                size: responsive.scale(18),
              ),
              SizedBox(width: responsive.scale(8)),
              Text(
                '$refute refuted',
                style: TextStyle(
                  fontSize: responsive.scaleFont(13),
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _InteractionRow extends StatelessWidget {
  final ReportData report;
  const _InteractionRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final userProv = context.watch<UserProvider>();
    final user = userProv.user;
    if (user == null) return const SizedBox.shrink();
    // Only regular users may confirm/refute. Admins/sysadmins cannot.
    if (!userProv.isUser) return const SizedBox.shrink();
    final canInteract = report.canUserInteract(user.userId);
    final confirmed = report.hasUserConfirmed(user.userId);
    final refuted = report.hasUserRefuted(user.userId);

    if (!canInteract) {
      return Text(
        'You cannot interact with this report.',
        style: TextStyle(
          fontSize: info.scaleFont(11),
          color: Colors.grey.shade600,
        ),
      );
    }

    // Enhanced visual affordance: subtle filled tint, stronger border and a
    // small check badge when selected. Uses cheap opacity animation only.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(
              Icons.thumb_up,
              size: info.scale(18),
              color: confirmed ? Colors.green : null,
            ),
            // Plain label (no check badge) — visual state shown via color/weight
            label: Text(
              'Confirm (${report.confirmCount})',
              style: TextStyle(
                fontSize: info.scaleFont(11),
                color: confirmed ? Colors.green.shade700 : null,
                fontWeight: confirmed ? FontWeight.w700 : null,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: confirmed
                  ? Colors.green.withValues(alpha: 0.08)
                  : null,
              side: BorderSide(
                color: confirmed ? Colors.green.shade700 : Colors.grey.shade300,
              ),
              padding: EdgeInsets.symmetric(vertical: info.scale(10)),
            ),
            onPressed: () =>
                context.read<ReportProvider>().confirm(report, user.userId),
          ),
        ),
        SizedBox(width: info.scale(8)),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(
              Icons.thumb_down,
              size: info.scale(18),
              color: refuted ? Colors.red : null,
            ),
            // Plain label (no check badge) — visual state shown via color/weight
            label: Text(
              'Refute (${report.refuteCount})',
              style: TextStyle(
                fontSize: info.scaleFont(11),
                color: refuted ? Colors.red.shade700 : null,
                fontWeight: refuted ? FontWeight.w700 : null,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: refuted
                  ? Colors.red.withValues(alpha: 0.08)
                  : null,
              side: BorderSide(
                color: refuted ? Colors.red.shade700 : Colors.grey.shade300,
              ),
              padding: EdgeInsets.symmetric(vertical: info.scale(10)),
            ),
            onPressed: () =>
                context.read<ReportProvider>().refute(report, user.userId),
          ),
        ),
      ],
    );
  }
}
