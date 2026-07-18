import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/lesson_progress.dart';
import 'package:vcroad/presentation/providers/learning.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';

class LessonCard extends StatelessWidget {
  final QuizMaterial lesson;
  final LessonProgress? progress;

  const LessonCard({super.key, required this.lesson, this.progress});

  Future<void> _handleStartLesson(BuildContext context) async {
    final provider = context.read<LearningProvider>();

    if (progress?.isLocked ?? true) {
      SnackbarUtils.showWarning(
        context,
        'Complete previous lessons to unlock this one',
      );
      return;
    }

    final success = await provider.startLesson(lesson.id);
    if (!success && context.mounted) {
      SnackbarUtils.showError(
        context,
        provider.error ?? 'Failed to start lesson',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final status = progress?.status ?? LessonStatus.locked;
    final isLocked = status == LessonStatus.locked;

    return Opacity(
      opacity: isLocked ? 0.6 : 1.0,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _getBorderColor(status), width: 2),
        ),
        child: InkWell(
          onTap: isLocked ? null : () => _handleStartLesson(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(info.scale(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Icon
                    Container(
                      padding: EdgeInsets.all(info.scale(8)),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: info.scale(24),
                      ),
                    ),
                    SizedBox(width: info.scale(12)),

                    // Lesson Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (lesson.lessonNumber != null)
                            Text(
                              'Lesson ${lesson.lessonNumber}',
                              style: TextStyle(
                                fontSize: info.scaleFont(11),
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          Text(
                            lesson.title,
                            style: TextStyle(
                              fontSize: info.scaleFont(16),
                              fontWeight: FontWeight.bold,
                              color: isLocked ? Colors.grey : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    _StatusBadge(status: status),
                  ],
                ),
                SizedBox(height: info.scale(12)),

                // Description
                if (lesson.description.isNotEmpty)
                  Text(
                    lesson.description,
                    style: TextStyle(
                      fontSize: info.scaleFont(13),
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                SizedBox(height: info.scale(12)),

                // Progress Bar (if in progress or completed)
                if (progress != null && (progress!.questionsAnswered > 0))
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${progress!.questionsAnswered}/${progress!.totalQuestions} questions',
                            style: TextStyle(
                              fontSize: info.scaleFont(11),
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${progress!.scorePercentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: info.scaleFont(11),
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: info.scale(6)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              progress!.questionsAnswered /
                              progress!.totalQuestions,
                          minHeight: info.scale(6),
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStatusColor(status),
                          ),
                        ),
                      ),
                      SizedBox(height: info.scale(8)),
                    ],
                  ),

                // Lesson Stats
                Row(
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: info.scale(16),
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: info.scale(4)),
                    Text(
                      '${lesson.questionCount} questions',
                      style: TextStyle(
                        fontSize: info.scaleFont(11),
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: info.scale(16)),
                    Icon(
                      Icons.stars_outlined,
                      size: info.scale(16),
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: info.scale(4)),
                    Text(
                      '${lesson.questions.fold(0, (sum, q) => sum + q.points)} points',
                      style: TextStyle(
                        fontSize: info.scaleFont(11),
                        color: Colors.grey[600],
                      ),
                    ),
                    if (progress?.attemptCount != null &&
                        progress!.attemptCount > 0) ...[
                      SizedBox(width: info.scale(16)),
                      Icon(
                        Icons.replay,
                        size: info.scale(16),
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: info.scale(4)),
                      Text(
                        '${progress!.attemptCount} attempt${progress!.attemptCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: info.scaleFont(11),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(LessonStatus status) {
    switch (status) {
      case LessonStatus.locked:
        return Colors.grey[300]!;
      case LessonStatus.available:
        return Colors.blue[300]!;
      case LessonStatus.inProgress:
        return Colors.orange[300]!;
      case LessonStatus.completed:
        return Colors.green[300]!;
    }
  }

  Color _getStatusColor(LessonStatus status) {
    switch (status) {
      case LessonStatus.locked:
        return Colors.grey;
      case LessonStatus.available:
        return Colors.blue;
      case LessonStatus.inProgress:
        return Colors.orange;
      case LessonStatus.completed:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(LessonStatus status) {
    switch (status) {
      case LessonStatus.locked:
        return Icons.lock;
      case LessonStatus.available:
        return Icons.play_circle_outline;
      case LessonStatus.inProgress:
        return Icons.pending_outlined;
      case LessonStatus.completed:
        return Icons.check_circle;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final LessonStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    String text;
    Color color;

    switch (status) {
      case LessonStatus.locked:
        text = 'Locked';
        color = Colors.grey;
        break;
      case LessonStatus.available:
        text = 'Start';
        color = Colors.blue;
        break;
      case LessonStatus.inProgress:
        text = 'Continue';
        color = Colors.orange;
        break;
      case LessonStatus.completed:
        text = 'Completed';
        color = Colors.green;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: info.scale(10),
        vertical: info.scale(5),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: info.scaleFont(11),
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
