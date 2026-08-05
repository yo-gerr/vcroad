import 'package:flutter/material.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/core/utils/format/date_time.dart';
import 'package:vcroad/presentation/shared/widgets/advisory_status_badge.dart';

/// Self-contained advisory card used by the advisory list (and its desktop
/// grid). Renders the status badge, category icon, schedule, contractor info,
/// and the admin action row (Activate/Deactivate, Delete, Download, Edit).
///
/// All actions are delegated through callbacks so the card stays a pure
/// presentation widget and is easy to test in isolation.
class AdvisoryCard extends StatelessWidget {
  final Advisory advisory;
  final dynamic responsive;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleStatus;

  const AdvisoryCard({
    super.key,
    required this.advisory,
    required this.responsive,
    this.canEdit = false,
    this.onTap,
    this.onDelete,
    this.onDownload,
    this.onEdit,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = AdvisoryCategory.findById(advisory.advisoryType);
    // Use persisted status only (no runtime computation)
    final status = advisory.status;

    // Status color comes from the model (single source of truth).
    final statusColor = status.color;
    // Brighten status accents in dark mode so the card border/header stays
    // visible on dark surfaces (same pattern as the connection chip).
    final accent =
        isDark ? (Color.lerp(statusColor, Colors.white, 0.35) ?? statusColor) : statusColor;

    // Subtle accent used for border / header background
    final borderColor = accent.withValues(alpha: isDark ? 0.7 : 0.55);
    final headerBg = statusColor.withValues(alpha: isDark ? 0.16 : 0.08);

    // Precompute formatted strings to avoid repeated formatter instantiation.
    final String startFriendly = DateFormatUtils.formatFriendly(
      advisory.startDate,
    );
    final String endFriendly = DateFormatUtils.formatFriendly(advisory.endDate);
    final String updatedFriendly = DateFormatUtils.formatFriendly(
      advisory.updatedAt,
    );

    // Increase card sizes slightly on mobile only (keeps desktop/tablet unchanged)
    final bool isMobile = (responsive?.isMobile ?? false);
    final double mobileBoost = isMobile ? 1.12 : 1.0;
    double s(double v) => responsive.scale(v) * mobileBoost;
    double sf(double v) => responsive.scaleFont(v) * (isMobile ? 1.06 : 1.0);

    // Dark icon color for light category accents (e.g. yellow) keeps the icon
    // readable; bright accents keep the white icon.
    final categoryIconColor =
        category != null && category.color.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Card(
      color: scheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // Use status-based border color for clearer signal (category color still used in header icon)
          color: borderColor,
          width: 2,
        ),
      ),
      child: Semantics(
        button: onTap != null,
        label: '${category?.title ?? advisory.advisoryType} advisory · '
            '${advisory.barangay} · ${status.label}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(s(12)),
                decoration: BoxDecoration(
                  // Blend category icon color with status background for consistent branding
                  color: headerBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    if (category != null)
                      Container(
                        width: s(48),
                        height: s(48),
                        decoration: BoxDecoration(
                          color: category.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          AdvisoryCategory.iconFor(category.id),
                          color: categoryIconColor,
                          size: s(26),
                        ),
                      ),
                  SizedBox(width: s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category?.title ?? advisory.advisoryType,
                          style: TextStyle(
                            fontSize: sf(17),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: s(6) * (isMobile ? 1 : 0.7)),

                        // Barangay badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: s(8),
                            vertical: s(4),
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: scheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: s(14),
                                color: scheme.onSurfaceVariant,
                              ),
                              SizedBox(width: s(6)),
                              Flexible(
                                child: Text(
                                  advisory.barangay,
                                  style: TextStyle(
                                    fontSize: sf(12),
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Place name chip (if available)
                        if (advisory.placeName != null &&
                            advisory.placeName!.isNotEmpty) ...[
                          SizedBox(height: s(6)),
                          Builder(
                            builder: (context) {
                              final Color baseBlue = Colors.blue.shade700;
                              final Color accentBlue =
                                  isDark
                                  ? (Color.lerp(baseBlue, Colors.white, 0.35) ??
                                        baseBlue)
                                  : baseBlue;
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: s(8),
                                  vertical: s(4),
                                ),
                                decoration: BoxDecoration(
                                  color: accentBlue.withValues(
                                    alpha: isDark ? 0.18 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accentBlue.withValues(alpha: 0.45),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.place,
                                      size: s(14),
                                      color: accentBlue,
                                    ),
                                    SizedBox(width: s(6)),
                                    Flexible(
                                      child: Text(
                                        advisory.placeName!,
                                        style: TextStyle(
                                          fontSize: sf(12),
                                          color: accentBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  AdvisoryStatusBadge(
                    status: status,
                    responsive: responsive,
                    paddingFactor: isMobile ? 1.0 : 0.9,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(s(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    advisory.reason,
                    style: TextStyle(fontSize: sf(15)),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: s(12)),

                  // Date range for one-time advisories. Recurring advisories show
                  // their schedule below instead, so hide the date range.
                  if (advisory.scheduleType == AdvisoryScheduleType.oneTime)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: s(16),
                          color: scheme.onSurfaceVariant,
                        ),
                        SizedBox(width: s(6)),
                        Expanded(
                          child: Text(
                            '$startFriendly — $endFriendly',
                            style: TextStyle(
                              fontSize: sf(13),
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Schedule Info
                  if (advisory.scheduleType ==
                      AdvisoryScheduleType.recurring) ...[
                    SizedBox(height: s(6)),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          size: s(16),
                          color: scheme.onSurfaceVariant,
                        ),
                        SizedBox(width: s(6)),
                        Flexible(
                          child: Text(
                            _formatSchedule(advisory, context),
                            style: TextStyle(
                              fontSize: sf(13),
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Meta: Updated timestamp (formatted via utils)
                  SizedBox(height: s(8)),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: s(14),
                        color: scheme.onSurfaceVariant,
                      ),
                      SizedBox(width: s(6)),
                      Expanded(
                        child: Text(
                          'Updated $updatedFriendly',
                          style: TextStyle(
                            fontSize: sf(12),
                            color: scheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Contractor Info (if applicable)
                  if (advisory.contractor != null) ...[
                    SizedBox(height: s(8)),
                    Container(
                      padding: EdgeInsets.all(s(8)),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(
                          alpha: isDark ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: s(16),
                            color: isDark
                                ? (Color.lerp(
                                        Colors.orange,
                                        Colors.white,
                                        0.35,
                                      ) ??
                                      Colors.orange)
                                : Colors.orange,
                          ),
                          SizedBox(width: s(8)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  advisory.contractor!,
                                  style: TextStyle(
                                    fontSize: sf(13),
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                if (advisory.contractorContact != null)
                                  Text(
                                    advisory.contractorContact!,
                                    style: TextStyle(
                                      fontSize: sf(12),
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            if (canEdit)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: s(8)),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick status toggle (Activate / Deactivate)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: onToggleStatus,
                          icon: Icon(
                            status == AdvisoryStatus.active
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: s(18),
                            color: status == AdvisoryStatus.active
                                ? Colors.orange.shade800
                                : Colors.green.shade700,
                          ),
                          label: Text(
                            status == AdvisoryStatus.active
                                ? 'Deactivate'
                                : 'Activate',
                            style: TextStyle(
                              color: status == AdvisoryStatus.active
                                  ? Colors.orange.shade800
                                  : Colors.green.shade700,
                              fontSize: sf(13),
                            ),
                          ),
                        ),
                      ),
                      // Delete / Download / Edit. Wrap instead of a fixed Row so
                      // buttons fall to a second line instead of overflowing on
                      // narrow screens or with large text scaling.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: s(2),
                        children: [
                          // Delete at the very left
                          TextButton.icon(
                            onPressed: onDelete,
                            icon: Icon(
                              Icons.delete,
                              size: s(18),
                              color: Colors.red,
                            ),
                            label: Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: sf(13),
                              ),
                            ),
                          ),

                          // Download
                          TextButton.icon(
                            onPressed: onDownload,
                            icon: Icon(Icons.download, size: s(18)),
                            label: Text(
                              'Download',
                              style: TextStyle(fontSize: sf(13)),
                            ),
                          ),

                          // Edit at the very right
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: Icon(Icons.edit, size: s(18)),
                            label: Text(
                              'Edit',
                              style: TextStyle(fontSize: sf(13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
    );
  }

  String _formatSchedule(Advisory advisory, BuildContext context) {
    if (advisory.weekdays == null || advisory.weekdays!.isEmpty) return '';

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selectedDays = advisory.weekdays!.map((d) => days[d - 1]).join(', ');

    if (advisory.recurringStartTime != null &&
        advisory.recurringEndTime != null) {
      return '$selectedDays (${advisory.recurringStartTime!.format(context)} - ${advisory.recurringEndTime!.format(context)})';
    }

    return selectedDays;
  }
}
