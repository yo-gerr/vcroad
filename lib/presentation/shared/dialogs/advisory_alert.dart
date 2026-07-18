import 'package:flutter/material.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/core/utils/format/date_time.dart';

class AdvisoryAlert {
  static Future<void> show({
    required BuildContext context,
    required Advisory advisory,
    VoidCallback? onView,
    VoidCallback? onMuteToday,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'New Advisory',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => _AdvisoryAlertDialog(
        advisory: advisory,
        onView: onView,
        onMuteToday: onMuteToday,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0, -0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }
}

class _AdvisoryAlertDialog extends StatelessWidget {
  final Advisory advisory;
  final VoidCallback? onView;
  final VoidCallback? onMuteToday;

  const _AdvisoryAlertDialog({
    required this.advisory,
    this.onView,
    this.onMuteToday,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(advisory.status);
    final headerBg = color.withValues(alpha: 0.08);
    final borderColor = color.withValues(alpha: 0.55);

    final start = DateFormatUtils.formatFriendly(advisory.startDate);
    final end = DateFormatUtils.formatFriendly(advisory.endDate);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _categoryColor(advisory.advisoryType),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _iconForCategory(advisory.advisoryType),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _categoryTitle(advisory.advisoryType),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  advisory.barangay,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(color, advisory.status),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advisory.reason,
                        style: const TextStyle(fontSize: 15),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      if (advisory.scheduleType == AdvisoryScheduleType.oneTime)
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$start — $end',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (advisory.scheduleType ==
                          AdvisoryScheduleType.recurring)
                        Row(
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatRecurring(context, advisory),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text(
                          'Dismiss',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      const Spacer(),
                      if (onMuteToday != null)
                        TextButton.icon(
                          onPressed: () {
                            onMuteToday?.call();
                            Navigator.of(context).maybePop();
                          },
                          icon: const Icon(Icons.notifications_off_outlined),
                          label: const Text('Mute today'),
                        ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF001278),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).maybePop();
                          onView?.call();
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('View'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(AdvisoryStatus s) {
    switch (s) {
      case AdvisoryStatus.active:
        return Colors.green;
      case AdvisoryStatus.scheduled:
        return Colors.orange;
      case AdvisoryStatus.inactive:
        return Colors.red;
      case AdvisoryStatus.expired:
        return Colors.grey;
    }
  }

  static Widget _statusBadge(Color color, AdvisoryStatus status) {
    final (icon, label) = switch (status) {
      AdvisoryStatus.active => (Icons.play_circle_filled, 'Active'),
      AdvisoryStatus.scheduled => (Icons.schedule, 'Scheduled'),
      AdvisoryStatus.inactive => (Icons.pause, 'Inactive'),
      AdvisoryStatus.expired => (Icons.history, 'Expired'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRecurring(BuildContext context, Advisory advisory) {
    if (advisory.weekdays == null || advisory.weekdays!.isEmpty) {
      return 'Recurring';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selected = advisory.weekdays!.map((d) => days[d - 1]).join(', ');
    if (advisory.recurringStartTime != null &&
        advisory.recurringEndTime != null) {
      return '$selected (${advisory.recurringStartTime!.format(context)} - ${advisory.recurringEndTime!.format(context)})';
    }
    return selected;
  }

  // Basic mappings matching AdvisoryScreen visuals
  static IconData _iconForCategory(String id) {
    switch (id) {
      case 'road_closure':
        return Icons.block;
      case 'stop_and_go':
        return Icons.traffic;
      case 'one_way':
        return Icons.arrow_forward;
      case 'construction':
        return Icons.construction;
      case 'partial_lane':
        return Icons.remove_road;
      case 'event':
        return Icons.event;
      default:
        return Icons.info;
    }
  }

  static Color _categoryColor(String id) {
    final match = advisoryCategories.where((c) => c.id == id);
    return match.isNotEmpty ? match.first.color : Colors.blueGrey;
  }

  static String _categoryTitle(String id) {
    final match = advisoryCategories.where((c) => c.id == id);
    return match.isNotEmpty ? match.first.title : 'Advisory';
  }
}
