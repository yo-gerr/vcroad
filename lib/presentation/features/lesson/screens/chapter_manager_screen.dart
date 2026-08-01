import 'package:flutter/material.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/repositories/lesson.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class ChapterManagerScreen extends StatefulWidget {
  const ChapterManagerScreen({super.key});

  @override
  State<ChapterManagerScreen> createState() => _ChapterManagerScreenState();
}

class _ChapterManagerScreenState extends State<ChapterManagerScreen> {
  final LessonService _service = LessonService.instance;
  List<Chapter> _chapters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final chapters = await _service.getChapters();
    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _loading = false;
    });
  }

  Future<void> _showChapterDialog({Chapter? chapter}) async {
    final isEdit = chapter != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: chapter?.name ?? '');
    final descCtrl = TextEditingController(text: chapter?.description ?? '');
    final nextOrderVal = chapter?.order ?? await _service.getNextChapterOrder();

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        if (!ctx.mounted) return const SizedBox();
        return AlertDialog(
          title: Text(isEdit ? 'Edit Chapter' : 'New Chapter'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Chapter Name',
                      hintText: 'e.g., Road Signs & Markings',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Chapter name is required';
                      if (value.length > 40) {
                        return 'Keep it under 40 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: ctx.scale(12)),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'What will users learn in this chapter?',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  if (isEdit)
                    Padding(
                      padding: EdgeInsets.only(top: ctx.scale(8)),
                      child: Text(
                        'Renaming moves existing lessons to the new name. Drag to reorder.',
                        style: TextStyle(
                          fontSize: ctx.scaleFont(12),
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  final bool ok;
                  if (isEdit) {
                    final updated = chapter.copyWith(
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                    );
                    await _service.updateChapter(
                      updated,
                      previousName: chapter.name,
                    );
                    ok = true;
                  } else {
                    ok = await _service.createChapter(
                      name: nameCtrl.text.trim(),
                      order: nextOrderVal,
                      description: descCtrl.text.trim(),
                    );
                    if (!ok && ctx.mounted) {
                      SnackbarUtils.showError(
                        ctx,
                        'A chapter with this name already exists',
                      );
                      return;
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) SnackbarUtils.showError(ctx, 'Error: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(
                isEdit ? 'Save Chapter' : 'Create Chapter',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (saved == true) await _load();
  }

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: Text(
          'Delete "${chapter.name}"?\nAll lessons and questions in this chapter will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      await _service.deleteChapter(chapter.id);
      if (mounted) SnackbarUtils.showSuccess(context, 'Chapter deleted');
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
        title: Text('Chapter Management', style: TextStyle(color: Colors.white, fontSize: context.scaleFont(18))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_chapter',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Chapter'),
        onPressed: () => _showChapterDialog(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chapters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: context.scale(64), color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(height: context.scale(16)),
                      Text('No chapters yet', style: TextStyle(fontSize: context.scaleFont(18), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      SizedBox(height: context.scale(8)),
                      ElevatedButton(onPressed: () => _showChapterDialog(), child: const Text('Create Chapter')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ReorderableListView.builder(
                    itemCount: _chapters.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      final ctx = context;
                      final items = [..._chapters];
                      final item = items.removeAt(oldIndex);
                      items.insert(newIndex, item);
                      setState(() => _chapters = items);
                      try {
                        await _service.updateChapterOrder(
                          items.map((c) => c.id).toList(),
                        );
                      } catch (e) {
                        if (ctx.mounted) {
                          SnackbarUtils.showError(ctx, 'Error: $e');
                        }
                        if (mounted) await _load();
                      }
                    },
                    itemBuilder: (_, i) {
                      final c = _chapters[i];
                      return Card(
                        key: ValueKey(c.id),
                        margin: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(4)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryAdaptive(context))),
                          ),
                          title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.scaleFont(16))),
                          subtitle: Text('${c.lessonCount} lessons${c.description != null && c.description!.isNotEmpty ? ' — ${c.description}' : ''}',
                              style: TextStyle(fontSize: context.scaleFont(13), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showChapterDialog(chapter: c)),
                              IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteChapter(c)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
