import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/providers/learning.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class LearningStatsHeader extends StatelessWidget {
  const LearningStatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final provider = context.watch<LearningProvider>();
    final stats = provider.stats;

    if (stats == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(info.scale(16)),
      padding: EdgeInsets.all(info.scale(20)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF001278), Color(0xFF0039E3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: info.scale(32),
              ),
              SizedBox(width: info.scale(12)),
              Expanded(
                child: Text(
                  'Your Learning Journey',
                  style: TextStyle(
                    fontSize: info.scaleFont(20),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: info.scale(20)),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Progress',
                    style: TextStyle(
                      fontSize: info.scaleFont(12),
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '${stats.overallProgress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: info.scaleFont(14),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: info.scale(8)),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: stats.overallProgress / 100,
                  minHeight: info.scale(8),
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ],
          ),
          SizedBox(height: info.scale(20)),

          // Stats Grid
          if (info.isMobile)
            Column(
              children: [
                _StatItem(
                  icon: Icons.school,
                  label: 'Completed',
                  value:
                      '${stats.lessonsCompleted}/${stats.totalLessonsAvailable}',
                ),
                SizedBox(height: info.scale(12)),
                _StatItem(
                  icon: Icons.auto_stories,
                  label: 'In Progress',
                  value: '${stats.lessonsInProgress}',
                ),
                SizedBox(height: info.scale(12)),
                _StatItem(
                  icon: Icons.stars,
                  label: 'Points',
                  value:
                      '${stats.totalPointsEarned}/${stats.totalPointsAvailable}',
                ),
                SizedBox(height: info.scale(12)),
                _StatItem(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value:
                      '${stats.currentStreak} ${(stats.currentStreak == 1 || stats.currentStreak == 0) ? 'day' : 'days'}',
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.school,
                    label: 'Completed',
                    value:
                        '${stats.lessonsCompleted}/${stats.totalLessonsAvailable}',
                  ),
                ),
                SizedBox(width: info.scale(12)),
                Expanded(
                  child: _StatItem(
                    icon: Icons.auto_stories,
                    label: 'In Progress',
                    value: '${stats.lessonsInProgress}',
                  ),
                ),
                SizedBox(width: info.scale(12)),
                Expanded(
                  child: _StatItem(
                    icon: Icons.stars,
                    label: 'Points',
                    value:
                        '${stats.totalPointsEarned}/${stats.totalPointsAvailable}',
                  ),
                ),
                SizedBox(width: info.scale(12)),
                Expanded(
                  child: _StatItem(
                    icon: Icons.local_fire_department,
                    label: 'Streak',
                    value:
                        '${stats.currentStreak} ${(stats.currentStreak == 1 || stats.currentStreak == 0) ? 'day' : 'days'}',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Container(
      padding: EdgeInsets.all(info.scale(12)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: info.scale(24)),
          SizedBox(width: info.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: info.scaleFont(11),
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: info.scale(2)),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: info.scaleFont(16),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
