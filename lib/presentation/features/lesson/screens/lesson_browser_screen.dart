import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/lesson_progress.dart';
import 'package:vcroad/data/repositories/lesson.dart';
import 'package:vcroad/data/repositories/lesson_progress.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/presentation/features/lesson/screens/lesson_screen.dart';
import 'package:vcroad/presentation/features/lesson/screens/lesson_review_screen.dart';
import 'package:vcroad/presentation/features/lesson/widgets/lesson_browser_card.dart';
import 'package:vcroad/presentation/features/lesson/widgets/lesson_stats_header.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class LessonBrowserScreen extends StatefulWidget {
  const LessonBrowserScreen({super.key});

  @override
  State<LessonBrowserScreen> createState() => _LessonBrowserScreenState();
}

class _LessonBrowserScreenState extends State<LessonBrowserScreen> {
  final LessonService _service = LessonService.instance;
  final LessonProgressService _progressService = LessonProgressService.instance;

  List<Chapter> _chapters = [];
  List<Lesson> _lessons = [];
  Map<String, LessonProgress> _progressMap = {};
  UserLearningStats _stats = UserLearningStats();
  bool _loading = true;
  bool _previewMode = false;
  final Set<String> _expandedChapters = {};

  Stream<List<LessonProgress>>? _progressStream;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = context.read<UserProvider>().user?.userId;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final results = await Future.wait([
        _service.getChapters(),
        _service.getLessons(publishedOnly: true),
      ]);

      final chapters = results[0] as List<Chapter>;
      final lessons = results[1] as List<Lesson>;

      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _lessons = lessons;
        for (final c in chapters) {
          _expandedChapters.add(c.id);
        }
      });

      final initialProgress = await _progressService.getUserProgress(userId);
      if (!mounted) return;
      if (initialProgress.isEmpty) {
        await _progressService.initializeUserProgress(userId);
        final refreshed = await _progressService.getUserProgress(userId);
        if (!mounted) return;
        _updateProgressMap(refreshed);
      } else {
        _updateProgressMap(initialProgress);
      }

      _progressStream = _progressService.watchUserProgress(userId);
      _progressStream!.listen((progress) {
        if (!mounted) return;
        _updateProgressMap(progress);
      });

      final statsStream = await _progressService.watchUserStats(userId);
      statsStream.listen((stats) {
        if (!mounted) return;
        setState(() => _stats = stats);
      });
    } catch (_) {
      // fall through
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateProgressMap(List<LessonProgress> progressList) {
    setState(() {
      _progressMap = {for (final p in progressList) p.lessonId: p};
    });
  }

  int get _dueForReviewCount => _progressMap.values
      .where((p) =>
          p.isCompleted &&
          p.nextReviewAt != null &&
          p.nextReviewAt!.isBefore(DateTime.now()))
      .length;

  List<Lesson> _lessonsForChapter(String chapterId) {
    return _lessons.where((l) => l.chapterId == chapterId).toList()
      ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        centerTitle: true,
        title: Text('Learn', style: TextStyle(color: Colors.white, fontSize: context.scaleFont(18))),
        actions: [
          if (context.read<UserProvider>().role != UserRole.user)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Preview', style: TextStyle(color: Colors.white70, fontSize: context.scaleFont(13))),
                Switch(
                  value: _previewMode,
                  onChanged: (v) => setState(() => _previewMode = v),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white38,
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lessons.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      LessonStatsHeader(
                        stats: _stats,
                        totalLessons: _lessons.length,
                        dueForReviewCount: _dueForReviewCount,
                        onDueReviewTap: () {
                          final lesson = _firstDueLesson();
                          if (lesson != null) _onLessonTap(lesson);
                        },
                      ),
                      if (_previewMode)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(context.scale(12)),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: context.scale(18), color: AppColors.primaryAdaptive(context)),
                              SizedBox(width: context.scale(8)),
                              Expanded(
                                child: Text(
                                  'Preview: all lessons are unlocked',
                                  style: TextStyle(fontSize: context.scaleFont(13), color: AppColors.primaryAdaptive(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final chapter in _chapters) ...[
                        _buildChapterHeader(chapter),
                        if (_expandedChapters.contains(chapter.id))
                          ..._lessonsForChapter(chapter.id).map((l) => LessonBrowserCard(
                            key: ValueKey(l.id),
                            lesson: l,
                            progress: _progressMap[l.id],
                            previewMode: _previewMode,
                            onTap: () => _onLessonTap(l),
                          )),
                        if (_expandedChapters.contains(chapter.id) && _lessonsForChapter(chapter.id).isEmpty)
                          Padding(
                            padding: EdgeInsets.all(context.scale(16)),
                            child: Text('No lessons available', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: context.scale(80), color: Theme.of(context).colorScheme.surfaceContainerHighest),
          SizedBox(height: context.scale(16)),
          Text('No lessons yet', style: TextStyle(fontSize: context.scaleFont(20), color: Theme.of(context).colorScheme.onSurfaceVariant)),
          SizedBox(height: context.scale(8)),
          Text('Check back later for new content', style: TextStyle(fontSize: context.scaleFont(14), color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildChapterHeader(Chapter chapter) {
    final chapterLessons = _lessonsForChapter(chapter.id);
    final completed = chapterLessons.where((l) => _progressMap[l.id]?.isCompleted ?? false).length;
    final isExpanded = _expandedChapters.contains(chapter.id);

    return Padding(
      padding: EdgeInsets.fromLTRB(context.scale(16), context.scale(16), context.scale(16), context.scale(4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedChapters.remove(chapter.id);
            } else {
              _expandedChapters.add(chapter.id);
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  color: AppColors.primaryAdaptive(context),
                  size: context.scale(22),
                ),
                SizedBox(width: context.scale(8)),
                Icon(Icons.folder, color: AppColors.primaryAdaptive(context), size: context.scale(20)),
                SizedBox(width: context.scale(8)),
                Expanded(
                  child: Text(
                    chapter.name,
                    style: TextStyle(fontSize: context.scaleFont(17), fontWeight: FontWeight.bold),
                  ),
                ),
                if (completed > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.scale(8), vertical: context.scale(3)),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completed/${chapterLessons.length}',
                      style: TextStyle(fontSize: context.scaleFont(12), color: Colors.green.shade700, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Text(
                    '${chapterLessons.length}',
                    style: TextStyle(fontSize: context.scaleFont(13), color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            if (completed > 0) ...[
              SizedBox(height: context.scale(8)),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: completed / chapterLessons.length,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Lesson? _firstDueLesson() {
    for (final l in _lessons) {
      final p = _progressMap[l.id];
      if (p?.isDueForReview ?? false) return l;
    }
    return null;
  }

  void _onLessonTap(Lesson lesson) async {
    final progress = _progressMap[lesson.id];
    if (progress?.isCompleted ?? false) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LessonReviewScreen(lesson: lesson),
        ),
      );
      if (mounted) _load();
      return;
    }
    if (_previewMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview mode — tap lesson to view content (coming soon)')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonScreen(lesson: lesson)),
    );

    if (mounted) _load();
  }
}
