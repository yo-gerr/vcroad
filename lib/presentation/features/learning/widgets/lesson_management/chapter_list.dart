import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/presentation/providers/lesson.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/lesson_card.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/reorder_dialog.dart';

class ChapterListView extends StatelessWidget {
  final List<ChapterGroup> chapterGroups;

  const ChapterListView({
    super.key,
    required this.chapterGroups,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final group = chapterGroups[index];
          return _ChapterSection(group: group);
        },
        childCount: chapterGroups.length,
      ),
    );
  }
}

class _ChapterSection extends StatefulWidget {
  final ChapterGroup group;

  const _ChapterSection({required this.group});

  @override
  State<_ChapterSection> createState() => _ChapterSectionState();
}

class _ChapterSectionState extends State<_ChapterSection> {
  bool _isExpanded = true;

  Future<void> _handleReorder() async {
    final result = await showDialog<List<QuizMaterial>>(
      context: context,
      builder: (_) => ReorderLessonsDialog(lessons: widget.group.lessons),
    );

    if (result != null && mounted) {
      final provider = context.read<LessonProvider>();
      final success = await provider.reorderLessons(result);

      if (mounted) {
        if (success) {
          SnackbarUtils.showSuccess(context, 'Lessons reordered successfully');
        } else {
          SnackbarUtils.showError(
            context,
            provider.error ?? 'Failed to reorder lessons',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: info.scale(16),
        vertical: info.scale(8),
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chapter Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(info.scale(16)),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: info.scale(28),
                    color: const Color(0xFF001278),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.category,
                          style: TextStyle(
                            fontSize: info.scaleFont(18),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF001278),
                          ),
                        ),
                        SizedBox(height: info.scale(4)),
                        Text(
                          '${widget.group.totalLessons} lessons • ${widget.group.totalQuestions} questions',
                          style: TextStyle(
                            fontSize: info.scaleFont(12),
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Reorder lessons in ${widget.group.category}',
                    child: IconButton(
                      icon: Icon(
                        Icons.reorder,
                        size: info.scale(24),
                      ),
                      onPressed: _handleReorder,
                      tooltip: 'Reorder lessons',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lessons List
          if (_isExpanded)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(info.scale(16)),
              itemCount: widget.group.lessons.length,
              separatorBuilder: (_, _) => SizedBox(height: info.scale(12)),
              itemBuilder: (context, index) {
                final lesson = widget.group.lessons[index];
                return LessonCard(lesson: lesson);
              },
            ),
        ],
      ),
    );
  }
}