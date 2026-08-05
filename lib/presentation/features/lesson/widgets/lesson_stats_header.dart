import 'package:flutter/material.dart';
import 'package:vcroad/core/constants/xp_constants.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/data/models/lesson_progress.dart';

class LessonStatsHeader extends StatelessWidget {
  final UserLearningStats stats;
  final int totalLessons;
  final int dueForReviewCount;
  final VoidCallback? onDueReviewTap;

  const LessonStatsHeader({
    super.key,
    required this.stats,
    required this.totalLessons,
    required this.dueForReviewCount,
    this.onDueReviewTap,
  });

  bool get _isEmpty => stats.completedLessons == 0 && stats.xp == 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        context.scale(16),
        context.scale(16),
        context.scale(16),
        context.scale(8),
      ),
      padding: EdgeInsets.all(context.scale(14)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isEmpty ? _buildEmpty(context) : _buildStats(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.menu_book_outlined,
          size: context.scale(22),
          color: AppColors.primaryAdaptive(context),
        ),
        SizedBox(width: context.scale(10)),
        Expanded(
          child: Text(
            'Start your first lesson to begin earning XP and building your streak',
            style: TextStyle(
              fontSize: context.scaleFont(13),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: context.scale(20),
              backgroundColor:
                  AppColors.primaryAdaptive(context).withValues(alpha: 0.12),
              child: Text(
                '${stats.level}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.scaleFont(15),
                  color: AppColors.primaryAdaptive(context),
                ),
              ),
            ),
            SizedBox(width: context.scale(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    XpConstants.getLevelTitle(stats.xp),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: context.scaleFont(15),
                    ),
                  ),
                  SizedBox(height: context.scale(1)),
                  Text(
                    _xpSubtitle(),
                    style: TextStyle(
                      fontSize: context.scaleFont(12),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.scale(10)),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: _xpProgress(),
            backgroundColor: Theme.of(context).colorScheme.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primaryAdaptive(context),
            ),
            minHeight: 6,
          ),
        ),
        SizedBox(height: context.scale(10)),
        Row(
          children: [
            _statItem(
              context,
              icon: Icons.local_fire_department,
              value: '${stats.currentStreak}',
              label: 'day streak',
              color: Colors.orange,
            ),
            _statItem(
              context,
              icon: Icons.check_circle_outline,
              value: '$completedLessons/$totalLessons',
              label: 'lessons',
              color: Colors.green,
            ),
            _statItem(
              context,
              icon: Icons.percent,
              value: '${stats.completionRate.round()}',
              label: 'complete',
              color: AppColors.primaryAdaptive(context),
            ),
            if (dueForReviewCount > 0)
              _statItem(
                context,
                icon: Icons.refresh,
                value: '$dueForReviewCount',
                label: 'due review',
                color: Colors.orange,
                onTap: onDueReviewTap,
              ),
          ],
        ),
      ],
    );
  }

  int get completedLessons => stats.completedLessons;

  String _xpSubtitle() {
    final xpToNext = XpConstants.getXpForNextLevel(stats.xp);
    if (xpToNext == -1) return '${stats.xp} XP · Max level';
    return '${stats.xp} XP · $xpToNext XP to next level';
  }

  double _xpProgress() {
    final currentLevel = XpConstants.getLevel(stats.xp);
    final currentMinXp = XpConstants.levels
        .firstWhere((l) => l.level == currentLevel)
        .minXp;
    final xpToNext = XpConstants.getXpForNextLevel(stats.xp);
    if (xpToNext == -1) return 1.0;
    final nextMinXp = stats.xp + xpToNext;
    return ((stats.xp - currentMinXp) / (nextMinXp - currentMinXp))
        .clamp(0.0, 1.0);
  }

  Widget _statItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: context.scale(15), color: color),
            SizedBox(width: context.scale(4)),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: context.scaleFont(14),
              ),
            ),
          ],
        ),
        SizedBox(height: context.scale(2)),
        Text(
          label,
          style: TextStyle(
            fontSize: context.scaleFont(11),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Expanded(
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: context.scale(4)),
                child: content,
              ),
            ),
    );
  }
}
