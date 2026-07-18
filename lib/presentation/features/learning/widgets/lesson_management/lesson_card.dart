import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/presentation/providers/lesson.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/shared/dialogs/confirmation.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/edit_lesson_dialog.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';

class LessonCard extends StatelessWidget {
  final QuizMaterial lesson;

  const LessonCard({super.key, required this.lesson});

  Future<void> _handleEdit(BuildContext context) async {
    final result = await showDialog<QuizMaterial>(
      context: context,
      builder: (_) => EditLessonDialog(lesson: lesson),
    );

    if (result != null && context.mounted) {
      final provider = context.read<LessonProvider>();
      bool success = false;

      // Show loading dialog while updating
      try {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const LoadingDialog(message: 'Saving changes...'),
        );
        success = await provider.updateLesson(result);
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // close loading
        }
      }

      if (context.mounted) {
        if (success) {
          SnackbarUtils.showSuccess(context, 'Lesson updated successfully');
        } else {
          SnackbarUtils.showError(
            context,
            provider.error ?? 'Failed to update lesson',
          );
        }
      }
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Delete Lesson',
        message:
            'Are you sure you want to delete this lesson? This action cannot be undone.',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<LessonProvider>();
      bool success = false;

      try {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const LoadingDialog(message: 'Deleting lesson...'),
        );
        success = await provider.deleteLesson(lesson.id);
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // close loading
        }
      }

      if (context.mounted) {
        if (success) {
          SnackbarUtils.showSuccess(context, 'Lesson deleted successfully');
        } else {
          SnackbarUtils.showError(
            context,
            provider.error ?? 'Failed to delete lesson',
          );
        }
      }
    }
  }

  Future<void> _handleTogglePublish(BuildContext context) async {
    final provider = context.read<LessonProvider>();
    final success = await provider.togglePublishStatus(
      lesson.id,
      !lesson.isPublished,
    );

    if (context.mounted) {
      if (success) {
        SnackbarUtils.showSuccess(
          context,
          lesson.isPublished ? 'Lesson unpublished' : 'Lesson published',
        );
      } else {
        SnackbarUtils.showError(
          context,
          provider.error ?? 'Failed to update publish status',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: lesson.isPublished ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(info.scale(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Lesson Number Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: info.scale(10),
                    vertical: info.scale(4),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF001278),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Lesson ${lesson.lessonNumber ?? 0}',
                    style: TextStyle(
                      fontSize: info.scaleFont(10),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: info.scale(8)),
                // Published Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: info.scale(10),
                    vertical: info.scale(4),
                  ),
                  decoration: BoxDecoration(
                    color: lesson.isPublished
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lesson.isPublished ? Icons.check_circle : Icons.edit,
                        size: info.scale(12),
                        color: lesson.isPublished
                            ? Colors.green
                            : Colors.orange,
                      ),
                      SizedBox(width: info.scale(4)),
                      Text(
                        lesson.isPublished ? 'Published' : 'Draft',
                        style: TextStyle(
                          fontSize: info.scaleFont(10),
                          fontWeight: FontWeight.w600,
                          color: lesson.isPublished
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Actions
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: info.scale(20)),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _handleEdit(context);
                        break;
                      case 'publish':
                        _handleTogglePublish(context);
                        break;
                      case 'delete':
                        _handleDelete(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: info.scale(18)),
                          SizedBox(width: info.scale(8)),
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'publish',
                      child: Row(
                        children: [
                          Icon(
                            lesson.isPublished
                                ? Icons.unpublished
                                : Icons.publish,
                            size: info.scale(18),
                          ),
                          SizedBox(width: info.scale(8)),
                          Text(lesson.isPublished ? 'Unpublish' : 'Publish'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            size: info.scale(18),
                            color: Colors.red,
                          ),
                          SizedBox(width: info.scale(8)),
                          const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: info.scale(12)),
            // Title
            Text(
              lesson.title,
              style: TextStyle(
                fontSize: info.scaleFont(16),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: info.scale(8)),
            // Description
            Text(
              lesson.description,
              style: TextStyle(
                fontSize: info.scaleFont(12),
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: info.scale(12)),
            // Footer Info
            Row(
              children: [
                Icon(Icons.quiz, size: info.scale(16), color: Colors.grey[600]),
                SizedBox(width: info.scale(4)),
                Text(
                  '${lesson.questionCount} questions',
                  style: TextStyle(
                    fontSize: info.scaleFont(12),
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: info.scale(16)),
                Icon(
                  Icons.timer,
                  size: info.scale(16),
                  color: Colors.grey[600],
                ),
                SizedBox(width: info.scale(4)),
                Text(
                  '${lesson.durationMinutes} min',
                  style: TextStyle(
                    fontSize: info.scaleFont(12),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
