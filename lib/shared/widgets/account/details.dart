import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/providers/account.dart';
import 'package:vcroad_v2/shared/services/account.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/utils/dialog/report.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/format/text.dart';
import 'package:vcroad_v2/shared/utils/format/date_time.dart';
import 'package:vcroad_v2/shared/utils/image/preview.dart'; // Add this import
import 'dart:math' as math; // added
import 'ban.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart'; // Add this import
import 'package:cloud_functions/cloud_functions.dart'; // Add this import
import 'package:vcroad_v2/shared/utils/dialog/confirmation.dart'; // Add this import
import 'package:vcroad_v2/shared/services/report.dart'; // <-- added
import 'package:vcroad_v2/shared/models/report.dart'; // <-- added

class AccountDetailsPage extends StatefulWidget {
  final UserDetails user;
  const AccountDetailsPage({super.key, required this.user});

  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> {
  bool _isVerifying = false;
  bool _isBanning = false;
  bool _isSchedulingDelete = false;

  // Cache futures for storagePath -> downloadUrl to avoid re-creating FutureBuilders on rebuilds
  final Map<String, Future<String?>> _urlFutures = {};

  @override
  void dispose() {
    _urlFutures.clear();
    super.dispose();
  }

  UserDetails get _currentUserDetails {
    final provider = context.watch<AccountProvider>();
    // Try to get the latest user from provider
    final updated = provider.users.firstWhere(
      (u) => u.userId == widget.user.userId,
      orElse: () => widget.user,
    );
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    // Use _currentUserDetails instead of widget.user everywhere
    final user = _currentUserDetails;
    final accountProv = context.watch<AccountProvider>();
    final currentUser = accountProv.currentUser;
    final isSysAdmin = currentUser?.role == UserRole.sysadmin;
    final isAdmin = currentUser?.role == UserRole.admin;
    // Permission model:
    // - sysadmin: allowed to perform ban/unban and schedule deletion of admin accounts
    // - admin: allowed to perform verification/unverification only
    final canBan = isSysAdmin;
    final canVerify = isAdmin;
    final canScheduleDelete =
        isSysAdmin &&
        user.role == UserRole.admin &&
        currentUser?.userId != user.userId;
    final isDesktop = context.isDesktop;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          TextFormat.titleCase(user.fullName),
          style: TextStyle(
            color: Colors.white,
            fontSize: context.scaleFont(18),
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            padding: EdgeInsets.all(context.scale(8)),
            iconSize: context.scale(32),
            icon: Image.asset(
              'assets/icons/return.webp',
              width: context.scale(24),
              height: context.scale(24),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: context.scale(24),
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final content = _buildContent(
            context,
            user, // <-- always use latest user
            canVerify,
            canBan,
            canScheduleDelete,
            isDesktop,
            constraints.maxWidth,
          );
          return RefreshIndicator(
            onRefresh: () async {},
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                vertical: context.scale(28),
                horizontal: context.scale(16),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 1100 : double.infinity,
                  ),
                  child: content,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserDetails user,
    bool canVerify,
    bool canBan,
    bool canScheduleDelete,
    bool isDesktop,
    double maxWidth,
  ) {
    final identity = _buildIdentitySection(context, user);
    final status = _buildStatusSection(
      context,
      user,
      canVerify,
      canBan,
      canScheduleDelete,
    );
    final personal = _buildPersonalInfoSection(context, user);
    final address = _buildAddressSection(context, user);
    final activity = _buildActivitySection(context, user);

    const gap = 24.0;
    final pageMax = math.min(maxWidth, 1100).toDouble();

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeaderRow(context, user),
          const SizedBox(height: 32),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: pageMax),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 24),
                        personal,
                        const SizedBox(height: 24),
                        activity,
                      ],
                    ),
                  ),
                  SizedBox(width: gap),
                  Flexible(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [status, const SizedBox(height: 24), address],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      );
    }

    // Mobile / narrow: vertical, centered, good spacing
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(context, user),
        const SizedBox(height: 24),
        identity,
        const SizedBox(height: 20),
        status,
        const SizedBox(height: 20),
        personal,
        const SizedBox(height: 20),
        address,
        const SizedBox(height: 20),
        activity,
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context, UserDetails user) {
    final isDesktop = context.isDesktop;
    final avatar = ImageService.buildCachedAvatar(
      imageUrl: null,
      radius: context.scale(48),
    );

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TextFormat.titleCase(user.fullName),
          style: TextStyle(
            fontSize: context.scaleFont(22),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.email,
          style: TextStyle(
            fontSize: context.scaleFont(15),
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        _roleChip(user.role, context),
      ],
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          avatar,
          SizedBox(width: context.scale(22)),
          Expanded(child: nameBlock),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        const SizedBox(height: 14),
        Text(
          TextFormat.titleCase(user.fullName),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.scaleFont(20),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.scaleFont(14),
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        _roleChip(user.role, context),
      ],
    );
  }

  Widget _roleChip(UserRole role, BuildContext context) {
    final color = switch (role) {
      UserRole.sysadmin => Colors.purple,
      UserRole.admin => Colors.blue,
      UserRole.user => Colors.teal,
    };
    final label = switch (role) {
      UserRole.sysadmin => 'Super Admin',
      UserRole.admin => 'Barangay Admin',
      UserRole.user => 'Road User',
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.scale(12),
        vertical: context.scale(6),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: context.scaleFont(13),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildIdentitySection(BuildContext context, UserDetails user) {
    final isDesktop = context.isDesktop;
    final imageWidgets = [
      _identityImageColumn(context, 'Selfie', user.selfiePath),
      _identityImageColumn(context, 'Valid ID', user.validIdPath),
    ];

    return _sectionCard(
      context,
      title: 'Identity',
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 340 : double.infinity,
          ),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              // Stack vertically if too narrow, else row
              final showRow = constraints.maxWidth > 260;
              return showRow
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: imageWidgets[0]),
                        SizedBox(width: 18),
                        Expanded(child: imageWidgets[1]),
                      ],
                    )
                  : Column(
                      children: [
                        imageWidgets[0],
                        SizedBox(height: 14),
                        imageWidgets[1],
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _identityImageColumn(
    BuildContext context,
    String label,
    String? storagePath,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: context.scaleFont(13),
          ),
        ),
        const SizedBox(height: 8),
        _buildImagePreviewInteractive(context, storagePath),
      ],
    );
  }

  Widget _buildImagePreviewInteractive(
    BuildContext context,
    String? storagePath,
  ) {
    const maxImageWidth = 180.0;
    final borderRadius = BorderRadius.circular(14);

    if (storagePath == null || storagePath.isEmpty) {
      return SizedBox(
        width: maxImageWidth,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: borderRadius,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No image',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ),
      );
    }

    final future = _urlFutures.putIfAbsent(
      storagePath,
      () => ImageService.getDownloadUrlCached(storagePath),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = math.min(constraints.maxWidth, maxImageWidth);
        return FutureBuilder<String?>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return SizedBox(
                width: imageWidth,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: borderRadius,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final url = snap.data;
            if (url == null) {
              return SizedBox(
                width: imageWidth,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: borderRadius,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Load failed',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }

            // Add fullscreen icon at bottom right
            return Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    showImagePreviewDialog(context, url);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: borderRadius,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: imageWidth,
                          height: imageWidth,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      showImagePreviewDialog(context, url);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                        semanticLabel: 'Fullscreen preview',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    UserDetails user,
    bool canVerify,
    bool canBan,
    bool canScheduleDelete,
  ) {
    final statusItems = <Widget>[
      _statusRow(context, 'Primary Status', user.primaryStatus),
      _statusRow(context, 'Verified', user.isVerified ? 'Yes' : 'No'),
      if (user.verifiedBy != null)
        _statusRow(
          context,
          'Verified By',
          _actorName(context, user.verifiedBy),
        ),
      if (user.verifiedAt != null)
        _statusRow(
          context,
          'Verified At',
          DateFormatUtils.formatFriendly(user.verifiedAt!),
        ),
      _statusRow(context, 'Banned', user.isBanned ? 'Yes' : 'No'),
      if (user.isBanned && user.banReason != null)
        _statusRow(context, 'Ban Reason', user.banReason!),
      if (user.isBanned && user.banBy != null)
        _statusRow(context, 'Banned By', _actorName(context, user.banBy)),
      if (user.isBanned && user.bannedAt != null)
        _statusRow(
          context,
          'Banned At',
          DateFormatUtils.formatFriendly(user.bannedAt!),
        ),
      if (user.isBanned && user.banExpiresAt != null)
        _statusRow(context, 'Ban Expires', user.remainingBanTime),
      if (!user.isBanned && user.unbannedBy != null)
        _statusRow(
          context,
          'Unbanned By',
          _actorName(context, user.unbannedBy),
        ),
      if (!user.isBanned && user.unbannedAt != null)
        _statusRow(
          context,
          'Unbanned At',
          DateFormatUtils.formatFriendly(user.unbannedAt!),
        ),
      if (user.isInactive && user.scheduledForDeletionAt != null)
        _statusRow(
          context,
          'Scheduled Deletion',
          DateFormatUtils.formatFriendly(user.scheduledForDeletionAt!),
        ),
    ];

    return _sectionCard(
      context,
      title: 'Status',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show flagged-reports viewer for normal user accounts
          if (user.role == UserRole.user) _actionButtonViewFlags(context, user),
          if (canVerify) _actionButtonVerify(context, user),
          if (canBan) _actionButtonBan(context, user),
          if (canScheduleDelete) _actionButtonScheduleDelete(context, user),
        ],
      ),
      child: Column(children: statusItems),
    );
  }

  Widget _actionButtonVerify(BuildContext context, UserDetails user) {
    return Padding(
      padding: EdgeInsets.only(left: context.scale(10)),
      child: ElevatedButton.icon(
        onPressed: _isVerifying ? null : () => _toggleVerify(user),
        icon: Icon(
          user.isVerified ? Icons.remove_done : Icons.verified,
          size: context.scale(18),
          color: Colors.white, // ensure icon is white
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: user.isVerified ? Colors.orange : Colors.green,
          foregroundColor: Colors.white, // ensures label text is white
          minimumSize: const Size(90, 38),
        ),
        label: _isVerifying
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                user.isVerified ? 'Unverify' : 'Verify',
                style: const TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  Widget _actionButtonBan(BuildContext context, UserDetails user) {
    return Padding(
      padding: EdgeInsets.only(left: context.scale(10)),
      child: ElevatedButton.icon(
        onPressed: _isBanning ? null : () => _toggleBan(user),
        icon: Icon(
          user.isBanned ? Icons.gpp_good : Icons.block,
          size: context.scale(18),
          color: Colors.white, // ensure icon is white
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: user.isBanned ? Colors.green : Colors.red,
          foregroundColor: Colors.white, // ensures label text is white
          minimumSize: const Size(90, 38),
        ),
        label: _isBanning
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                user.isBanned ? 'Unban' : 'Ban',
                style: const TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  Widget _actionButtonScheduleDelete(BuildContext context, UserDetails user) {
    return Padding(
      padding: EdgeInsets.only(left: context.scale(10)),
      child: Semantics(
        label: 'Schedule deletion for admin account',
        button: true,
        child: ElevatedButton.icon(
          onPressed: _isSchedulingDelete ? null : () => _scheduleDelete(user),
          icon: Icon(
            Icons.delete_forever,
            size: context.scale(18),
            color: Colors.white,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 38),
          ),
          label: _isSchedulingDelete
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Schedule Delete',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ),
    );
  }

  Widget _actionButtonViewFlags(BuildContext context, UserDetails user) {
    return Padding(
      padding: EdgeInsets.only(left: context.scale(10)),
      child: OutlinedButton.icon(
        onPressed: () => _showFlaggedReports(context, user),
        icon: Icon(
          Icons.flag,
          size: context.scale(18),
          color: Colors.orange.shade700,
        ),
        label: Text('Flagged', style: TextStyle(color: Colors.orange.shade700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.orange.shade700),
          minimumSize: const Size(90, 38),
        ),
      ),
    );
  }

  Future<void> _showFlaggedReports(BuildContext context, UserDetails user) {
    final info = context.responsive;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF001278),
              elevation: 0,
              leading: Semantics(
                label: 'Back',
                button: true,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
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
                'Flagged Reports by ${user.firstName}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: info.scaleFont(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: StreamBuilder<List<ReportData>>(
              stream: ReportService.instance.getUserReports(
                user.userId,
                activeOnly: false,
                limit: 500,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? <ReportData>[];
                final flagged = all.where((r) => r.isFlagged).toList();
                if (flagged.isEmpty) {
                  return Center(
                    child: Text(
                      'No flagged reports.',
                      style: TextStyle(fontSize: info.scaleFont(14)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.all(info.scale(12)),
                  itemCount: flagged.length,
                  separatorBuilder: (_, __) => SizedBox(height: info.scale(12)),
                  itemBuilder: (context, i) {
                    final r = flagged[i];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            ReportDetailsDialog.show(context, r.reportId),
                        child: Padding(
                          padding: EdgeInsets.all(info.scale(12)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: info.scale(44),
                                height: info.scale(44),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(info.scale(6)),
                                  child: Image.asset(
                                    r.category.asset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.report,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: info.scale(12)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            r.category.label,
                                            style: TextStyle(
                                              fontSize: info.scaleFont(14),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: info.scale(8),
                                            vertical: info.scale(4),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange,
                                            ),
                                          ),
                                          child: Text(
                                            r.statusLabel,
                                            style: TextStyle(
                                              fontSize: info.scaleFont(11),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: info.scale(6)),
                                    Text(
                                      '${r.barangay} • ${r.timeAgo}',
                                      style: TextStyle(
                                        fontSize: info.scaleFont(12),
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: info.scale(8)),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.thumb_up,
                                          size: info.scale(16),
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: info.scale(6)),
                                        Text(
                                          '${r.confirmCount}',
                                          style: TextStyle(
                                            fontSize: info.scaleFont(12),
                                          ),
                                        ),
                                        SizedBox(width: info.scale(12)),
                                        Icon(
                                          Icons.thumb_down,
                                          size: info.scale(16),
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: info.scale(6)),
                                        Text(
                                          '${r.refuteCount}',
                                          style: TextStyle(
                                            fontSize: info.scaleFont(12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleVerify(UserDetails user) async {
    // Only admins may verify/unverify
    final accountProv = context.read<AccountProvider>();
    final currentUser = accountProv.currentUser;
    if (currentUser == null || currentUser.role != UserRole.admin) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Permission denied: only admins can verify users',
        );
      }
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await AccountService.instance.updateVerificationStatus(
        userId: user.userId,
        isVerified: !user.isVerified,
        verifiedBy: currentUser.userId,
      );
      final updated = user.copyWith(
        isVerified: !user.isVerified,
        verifiedBy: !user.isVerified ? currentUser.userId : null,
        verifiedAt: !user.isVerified ? DateTime.now() : null,
      );
      accountProv.updateUser(updated);
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          updated.isVerified ? 'User verified.' : 'User unverified.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Verification failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _toggleBan(UserDetails user) async {
    // Only sysadmins may ban/unban
    final accountProv = context.read<AccountProvider>();
    final currentUser = accountProv.currentUser;
    if (currentUser == null || currentUser.role != UserRole.sysadmin) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Permission denied: only sysadmins can ban users',
        );
      }
      return;
    }

    final willBan = !user.isBanned;
    if (!willBan) {
      // Unban flow with confirmation (use ConfirmationDialog)
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const ConfirmationDialog(
          title: 'Unban user',
          message: 'Are you sure you want to unban this user?',
          confirmText: 'Unban',
          cancelText: 'Cancel',
        ),
      );
      if (confirmed != true) return;

      setState(() => _isBanning = true);
      try {
        // Call backend unban function
        final functions = FirebaseFunctions.instance;
        await functions.httpsCallable('unbanUser').call({
          'userId': user.userId,
          'adminId': currentUser.userId,
        });

        final updated = user.copyWith(
          isBanned: false,
          banReason: null,
          banBy: null,
          bannedAt: null,
          unbannedBy: currentUser.userId,
          unbannedAt: DateTime.now(),
          banType: null,
          banDuration: null,
          banExpiresAt: null,
        );
        accountProv.updateUser(updated);
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'User unbanned.');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Unban failed: $e');
        }
      } finally {
        if (mounted) setState(() => _isBanning = false);
      }
      return;
    }

    // Ban flow: show dialog to collect duration + reason
    final result = await showBanDialog(context);
    if (result == null) return; // cancelled by user

    setState(() => _isBanning = true);
    try {
      final banType = result.isPermanent ? 'permanent' : 'temporary';
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('banUser').call({
        'userId': user.userId,
        'reason': result.reason,
        'adminId': currentUser.userId,
        'banType': banType,
        'banDuration': result.isPermanent ? null : result.days,
      });

      final expiresAt = result.isPermanent
          ? null
          : DateTime.now().add(Duration(days: result.days ?? 0));
      final updated = user.copyWith(
        isBanned: true,
        banReason: result.reason,
        banBy: currentUser.userId,
        bannedAt: DateTime.now(),
        banType: banType,
        banDuration: result.days,
        banExpiresAt: expiresAt,
      );

      accountProv.updateUser(updated);
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'User banned.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Ban action failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isBanning = false);
    }
  }

  Future<void> _scheduleDelete(UserDetails user) async {
    final accountProv = context.read<AccountProvider>();
    final currentUser = accountProv.currentUser;
    if (currentUser == null || currentUser.role != UserRole.sysadmin) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Permission denied: only sysadmins can schedule admin deletion.',
        );
      }
      return;
    }
    if (user.role != UserRole.admin) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Only admin accounts can be scheduled for deletion by a sysadmin.',
        );
      }
      return;
    }
    if (user.userId == currentUser.userId) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'You cannot schedule deletion for your own account.',
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Schedule account deletion',
        message:
            'This will schedule the admin account for deletion in 30 days. The account will be soft-deleted and can be restored before the scheduled date. Continue?',
        confirmText: 'Schedule',
        cancelText: 'Cancel',
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSchedulingDelete = true);
    try {
      await AccountService.instance.scheduleForDeletion(user.userId);

      // Update local UI optimistically: scheduledForDeletionAt ~ 30 days from now
      final scheduledAt = DateTime.now().add(const Duration(days: 30));
      final updated = user.copyWith(scheduledForDeletionAt: scheduledAt);
      accountProv.updateUser(updated);

      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Account scheduled for deletion (30 days).',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to schedule deletion: $e');
      }
    } finally {
      if (mounted) setState(() => _isSchedulingDelete = false);
    }
  }

  /// Return a display name for an actor (verifiedBy / banBy / unbannedBy).
  /// Uses AccountProvider cache if available; triggers a background fetch
  /// (non-blocking) when not cached so the UI updates when the name arrives.
  String _actorName(BuildContext context, String? userId) {
    final prov = Provider.of<AccountProvider>(context, listen: false);
    final display = prov.getActorDisplayNameOrId(userId);

    // If not cached, trigger a background fetch once (provider guards duplicates)
    if (userId != null &&
        userId.isNotEmpty &&
        prov.getActorDisplayName(userId) == null) {
      // schedule microtask to avoid calling async work synchronously during build
      Future.microtask(() => prov.ensureActorName(userId));
    }

    return display;
  }

  Widget _buildPersonalInfoSection(BuildContext context, UserDetails user) {
    return _sectionCard(
      context,
      title: 'Personal Information',
      child: Column(
        children: [
          _infoRow(context, 'First Name', TextFormat.titleCase(user.firstName)),
          if ((user.middleName ?? '').isNotEmpty)
            _infoRow(
              context,
              'Middle Name',
              TextFormat.titleCase(user.middleName!),
            ),
          _infoRow(context, 'Last Name', TextFormat.titleCase(user.lastName)),
          if ((user.suffix ?? '').isNotEmpty)
            _infoRow(context, 'Suffix', TextFormat.titleCase(user.suffix!)),
          _infoRow(context, 'Email', user.email),
          _infoRow(context, 'Phone', user.phoneNumber),
          _infoRow(
            context,
            'Created',
            DateFormatUtils.formatFriendly(user.createdAt),
          ),
          if (user.updatedAt != null)
            _infoRow(
              context,
              'Updated',
              DateFormatUtils.formatFriendly(user.updatedAt!),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context, UserDetails user) {
    return _sectionCard(
      context,
      title: 'Address',
      child: Column(
        children: [
          _infoRow(context, 'House Number', user.houseNumber),
          _infoRow(context, 'Street', TextFormat.titleCase(user.street)),
          _infoRow(
            context,
            'Barangay',
            TextFormat.locality(user.barangay.name),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context, UserDetails user) {
    return _sectionCard(
      context,
      title: 'Activity & Stats',
      child: Column(
        children: [
          _infoRow(context, 'Lessons Finished', '${user.lessonsFinishedCount}'),
          _infoRow(context, 'Verified Reports', '${user.verifiedReportsCount}'),
          _infoRow(context, 'Flagged Reports', '${user.flaggedReportsCount}'),
          _infoRow(
            context,
            'Confirm Reactions',
            '${user.confirmReactionsCount}',
          ),
          if (user.lastLoginAt != null)
            _infoRow(
              context,
              'Last Login',
              DateFormatUtils.formatFriendly(user.lastLoginAt!),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      shadowColor: Colors.black12,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.scale(18),
          horizontal: context.scale(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: context.scaleFont(17),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.scale(10)),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final labelWidth = (constraints.maxWidth * 0.32).clamp(110.0, 240.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: context.scaleFont(14),
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: context.scaleFont(14)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusRow(BuildContext context, String label, String value) {
    final formattedLabel = TextFormat.titleCase(label);
    final formattedValue = TextFormat.titleCase(value);

    Color color;
    switch (value.toLowerCase()) {
      case 'banned':
        color = Colors.red;
        break;
      case 'inactive':
        color = Colors.orange;
        break;
      case 'verified':
        color = Colors.green;
        break;
      default:
        color = Colors.grey.shade600;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: context.scale(10)),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final labelWidth = (constraints.maxWidth * 0.32).clamp(110.0, 240.0);
          return Row(
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  formattedLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: context.scaleFont(14),
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        formattedValue,
                        style: TextStyle(
                          fontSize: context.scaleFont(14),
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
