import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/presentation/providers/lesson.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/widgets/stats/stats.dart'; // <-- use shared stats util

class LessonStatsCards extends StatelessWidget {
  const LessonStatsCards({super.key});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final provider = context.watch<LessonProvider>();

    final stats = [
      StatsUtils(
        label: 'Total Lessons',
        value: provider.totalLessons.toString(),
        icon: Icons.school,
        color: const Color(0xFF001278),
      ),
      StatsUtils(
        label: 'Total Questions',
        value: provider.totalQuestions.toString(),
        icon: Icons.quiz,
        color: Colors.green,
      ),
      StatsUtils(
        label: 'Published',
        value: provider.publishedCount.toString(),
        icon: Icons.check_circle,
        color: Colors.blue,
      ),
      StatsUtils(
        label: 'Drafts',
        value: provider.draftCount.toString(),
        icon: Icons.edit,
        color: Colors.orange,
      ),
    ];

    // StatsRow adapts for mobile/tablet/desktop and preserves spacing/responsiveness
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: info.scale(0)),
      child: StatsRow(
        stats: stats,
        responsive: info,
        spacing: 12,
        runSpacing: 12,
        cardElevation: 2,
      ),
    );
  }
}
