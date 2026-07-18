import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/lesson_progress.dart';
import 'package:vcroad/presentation/providers/learning.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_card.dart';

class LessonList extends StatelessWidget {
  const LessonList({super.key});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final provider = context.watch<LearningProvider>();
    final lessonsWithProgress = provider.getLessonsWithProgress();

    if (lessonsWithProgress.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: info.scale(64),
                color: Colors.grey[400],
              ),
              SizedBox(height: info.scale(16)),
              Text(
                'No lessons available yet',
                style: TextStyle(
                  fontSize: info.scaleFont(16),
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: info.scale(8)),
              Text(
                'Check back later for new content',
                style: TextStyle(
                  fontSize: info.scaleFont(12),
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group by chapter
    final Map<String, List<MapEntry<QuizMaterial, LessonProgress?>>> grouped =
        {};
    for (final entry in lessonsWithProgress.entries) {
      final category = entry.key.chapterCategory;
      grouped.putIfAbsent(category, () => []);
      grouped[category]!.add(entry);
    }

    // Sort chapters by order
    final sortedChapters = grouped.keys.toList()
      ..sort((a, b) {
        final aOrder = lessonsWithProgress.keys
            .firstWhere((l) => l.chapterCategory == a)
            .chapterOrder;
        final bOrder = lessonsWithProgress.keys
            .firstWhere((l) => l.chapterCategory == b)
            .chapterOrder;
        return aOrder.compareTo(bOrder);
      });

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = sortedChapters[index];
        final lessons = grouped[category]!;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: info.scale(16),
            vertical: info.scale(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chapter Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: info.scale(16),
                  vertical: info.scale(12),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF001278).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: info.scale(20),
                      color: const Color(0xFF001278),
                    ),
                    SizedBox(width: info.scale(8)),
                    Expanded(
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: info.scaleFont(16),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF001278),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: info.scale(8),
                        vertical: info.scale(4),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF001278),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${lessons.where((e) => e.value?.isCompleted ?? false).length}/${lessons.length}',
                        style: TextStyle(
                          fontSize: info.scaleFont(11),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: info.scale(12)),

              // Lessons
              ...lessons.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(bottom: info.scale(12)),
                  child: LessonCard(lesson: entry.key, progress: entry.value),
                );
              }),
            ],
          ),
        );
      }, childCount: sortedChapters.length),
    );
  }
}
