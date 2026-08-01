import 'package:flutter/material.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/repositories/lesson.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/features/lesson/screens/chapter_manager_screen.dart';
import 'package:vcroad/presentation/features/lesson/widgets/lesson_dialog.dart';
import 'package:vcroad/presentation/features/lesson/widgets/question_editor.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final LessonService _service = LessonService.instance;
  List<Chapter> _chapters = [];
  List<Lesson> _lessons = [];
  bool _loading = true;
  final Set<String> _collapsed = {};
  String _query = '';

  bool get _hasQuery => _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.getChapters(),
      _service.getLessons(),
    ]);
    if (!mounted) return;
    setState(() {
      _chapters = results[0] as List<Chapter>;
      _lessons = results[1] as List<Lesson>;
      _loading = false;
    });
  }

  List<Lesson> _lessonsForChapter(String chapterId) {
    final q = _query.trim().toLowerCase();
    return _lessons
        .where((l) => l.chapterId == chapterId)
        .where((l) => q.isEmpty || l.title.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
  }

  int get _nextLessonNumber {
    if (_lessons.isEmpty) return 1;
    return _lessons.map((l) => l.lessonNumber).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _showLessonDialog({Lesson? lesson}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => LessonDialog(
        lesson: lesson,
        chapters: _chapters,
        nextLessonNumber: _nextLessonNumber,
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Delete "${lesson.title}"?\nAll questions will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteLesson(lesson.id);
      if (mounted) SnackbarUtils.showSuccess(context, 'Lesson deleted');
      await _load();
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Error: $e');
    }
  }

  Future<void> _togglePublish(Lesson lesson) async {
    try {
      await _service.togglePublishStatus(lesson.id, !lesson.isPublished);
      if (mounted) {
        SnackbarUtils.showSuccess(context, lesson.isPublished ? 'Unpublished' : 'Published');
      }
      await _load();
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: Text('Lesson Management', style: TextStyle(color: Colors.white, fontSize: context.scaleFont(18))),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.folder, color: Colors.white, size: 20),
            label: const Text('Chapters', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChapterManagerScreen()));
              await _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_lesson',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Lesson'),
        onPressed: _chapters.isEmpty
            ? () {
                SnackbarUtils.showError(context, 'Create a chapter first');
              }
            : () => _showLessonDialog(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _chapters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined, size: context.scale(64), color: Theme.of(context).colorScheme.onSurfaceVariant),
                          SizedBox(height: context.scale(16)),
                          Text('No chapters yet', style: TextStyle(fontSize: context.scaleFont(18), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          SizedBox(height: context.scale(8)),
                          ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChapterManagerScreen()));
                              await _load();
                            },
                            child: const Text('Create Chapter'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        _buildSearchField(context),
                        _buildSummaryHeader(context),
                        for (final chapter in _chapters) ...[
                          _buildChapterHeader(chapter),
                          if (!_collapsed.contains(chapter.id) || _hasQuery) ...[
                            ..._lessonsForChapter(chapter.id).map((l) => _buildLessonCard(l)),
                            if (_lessonsForChapter(chapter.id).isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(8)),
                                child: Text(
                                  _hasQuery ? 'No matching lessons' : 'No lessons in this chapter',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildChapterHeader(Chapter chapter) {
    final collapsed = _collapsed.contains(chapter.id);
    return InkWell(
      onTap: () => setState(() {
        if (collapsed) {
          _collapsed.remove(chapter.id);
        } else {
          _collapsed.add(chapter.id);
        }
      }),
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.scale(16), context.scale(16), context.scale(16), context.scale(4)),
        child: Row(
          children: [
            Icon(Icons.folder, color: AppColors.primaryAdaptive(context), size: context.scale(20)),
            SizedBox(width: context.scale(8)),
            Expanded(
              child: Text(chapter.name, style: TextStyle(fontSize: context.scaleFont(18), fontWeight: FontWeight.bold)),
            ),
            Text('${_lessonsForChapter(chapter.id).length} lessons', style: TextStyle(fontSize: context.scaleFont(13), color: Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(width: context.scale(4)),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.scale(16), context.scale(12), context.scale(16), context.scale(4)),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search lessons…',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Clear search',
                  onPressed: () => setState(() => _query = ''),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final published = _lessons.where((l) => l.isPublished).length;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.scale(16), context.scale(4), context.scale(16), context.scale(8)),
      child: Wrap(
        spacing: context.scale(8),
        runSpacing: context.scale(4),
        children: [
          _chip(context, Icons.folder_outlined, '${_chapters.length} Chapters'),
          _chip(context, Icons.menu_book_outlined, '${_lessons.length} Lessons'),
          _chip(context, Icons.public, '$published Published'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.scale(10), vertical: context.scale(6)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.scale(16), color: AppColors.primaryAdaptive(context)),
          SizedBox(width: context.scale(6)),
          Text(label, style: TextStyle(fontSize: context.scaleFont(12), fontWeight: FontWeight.w600, color: AppColors.primaryAdaptive(context))),
        ],
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(4)),
      child: Padding(
        padding: EdgeInsets.all(context.scale(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: context.scale(14),
                  backgroundColor: lesson.isPublished ? Colors.green.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text('${lesson.lessonNumber}', style: TextStyle(fontSize: context.scaleFont(12), fontWeight: FontWeight.bold, color: lesson.isPublished ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                SizedBox(width: context.scale(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.scaleFont(15)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: context.scale(2)),
                      Text('${lesson.durationMinutes} min | ${lesson.pointsAvailable} pts', style: TextStyle(fontSize: context.scaleFont(12), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Switch(
                  value: lesson.isPublished,
                  onChanged: (_) => _togglePublish(lesson),
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
            SizedBox(height: context.scale(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.quiz_outlined, size: 20),
                  tooltip: 'Edit Questions',
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionEditor(lesson: lesson)));
                    await _load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit Lesson',
                  onPressed: () => _showLessonDialog(lesson: lesson),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  tooltip: 'Delete Lesson',
                  onPressed: () => _deleteLesson(lesson),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
