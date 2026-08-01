import 'package:flutter/material.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/lesson_progress.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class LessonBrowserCard extends StatelessWidget {
  final Lesson lesson;
  final LessonProgress? progress;
  final VoidCallback? onTap;
  final bool previewMode;

  const LessonBrowserCard({
    super.key,
    required this.lesson,
    this.progress,
    this.onTap,
    this.previewMode = false,
  });

  bool get _isLocked => !previewMode && (progress?.isLocked ?? true);
  bool get _isCompleted => progress?.isCompleted ?? false;
  bool get _inProgress => (progress?.questionsAnswered ?? 0) > 0 && !_isCompleted;
  bool get _isDueForReview =>
      _isCompleted &&
      progress?.nextReviewAt != null &&
      progress!.nextReviewAt!.isBefore(DateTime.now());

  Color _accentColor(BuildContext context) {
    if (_isCompleted) return Colors.green;
    if (_inProgress) return AppColors.primaryAdaptive(context);
    if (_isDueForReview) return Colors.orange;
    if (_isLocked) return const Color(0xFF9E9E9E);
    return AppColors.primaryAdaptive(context);
  }

  IconData get _statusIcon {
    if (_isCompleted) return Icons.check_circle;
    if (_inProgress) return Icons.play_circle_filled;
    if (_isDueForReview) return Icons.refresh;
    if (_isLocked) return Icons.lock;
    return Icons.play_arrow;
  }

  int get _questionsAnswered => progress?.questionsAnswered ?? 0;
  int get _totalQuestions => progress?.totalQuestions ?? 0;
  double get _progressValue =>
      _totalQuestions > 0 ? _questionsAnswered / _totalQuestions : 0.0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isLocked ? 0.5 : 1.0,
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _inProgress
              ? BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLocked ? null : onTap,
          child: Padding(
            padding: EdgeInsets.all(context.scale(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: context.scale(18),
                      backgroundColor: _accentColor(context).withValues(alpha: 0.12),
                      child: Text(
                        '${lesson.lessonNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.scaleFont(14),
                          color: _accentColor(context),
                        ),
                      ),
                    ),
                    SizedBox(width: context.scale(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: context.scaleFont(15),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.scale(2)),
                          Row(
                            children: [
                              Icon(_statusIcon, size: context.scale(14), color: _accentColor(context)),
                              SizedBox(width: context.scale(4)),
                              Text(
                                _statusLabel,
                                style: TextStyle(
                                  fontSize: context.scaleFont(12),
                                  color: _accentColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: context.scale(12)),
                              Icon(Icons.timer_outlined, size: context.scale(14), color: Theme.of(context).colorScheme.onSurfaceVariant),
                              SizedBox(width: context.scale(3)),
                              Text(
                                '${lesson.durationMinutes} min',
                                style: TextStyle(fontSize: context.scaleFont(12), color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                              SizedBox(width: context.scale(12)),
                              Icon(Icons.stars_outlined, size: context.scale(14), color: Theme.of(context).colorScheme.onSurfaceVariant),
                              SizedBox(width: context.scale(3)),
                              Text(
                                '${lesson.pointsAvailable} pts',
                          style: TextStyle(fontSize: context.scaleFont(12), color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_inProgress) ...[
                  SizedBox(height: context.scale(10)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      minHeight: 6,
                    ),
                  ),
                  SizedBox(height: context.scale(4)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$_questionsAnswered / $_totalQuestions',
                      style: TextStyle(fontSize: context.scaleFont(11), color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
                if (_isCompleted) ...[
                  SizedBox(height: context.scale(6)),
                  Row(
                    children: [
                      Icon(Icons.emoji_events, size: context.scale(16), color: Colors.amber),
                      SizedBox(width: context.scale(4)),
                      Text(
                        'Score: ${progress!.score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: context.scaleFont(13),
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (progress!.pointsEarned > 0) ...[
                        SizedBox(width: context.scale(12)),
                        Text(
                          '${progress!.pointsEarned} pts earned',
                          style: TextStyle(fontSize: context.scaleFont(12), color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
                if (_isDueForReview) ...[
                  SizedBox(height: context.scale(6)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(3)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Due for review',
                      style: TextStyle(fontSize: context.scaleFont(12), color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                if (previewMode && !_isCompleted) ...[
                  SizedBox(height: context.scale(6)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(3)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Preview mode',
                      style: TextStyle(fontSize: context.scaleFont(11), color: AppColors.primaryAdaptive(context), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _statusLabel {
    if (_isCompleted) return 'Completed';
    if (_inProgress) return 'In Progress';
    if (_isDueForReview) return 'Review';
    if (_isLocked) return 'Locked';
    return 'Available';
  }
}
