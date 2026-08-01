import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/repositories/lesson.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class LessonDialog extends StatefulWidget {
  final Lesson? lesson;
  final List<Chapter> chapters;
  final int nextLessonNumber;

  const LessonDialog({
    super.key,
    this.lesson,
    required this.chapters,
    required this.nextLessonNumber,
  });

  @override
  State<LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<LessonDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _durCtrl;
  late TextEditingController _tagsCtrl;
  String _selectedChapterId = '';
  int _lessonNumber = 1;
  bool _isPublished = false;
  bool _saving = false;

  bool get _isEditing => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    _titleCtrl = TextEditingController(text: l?.title ?? '');
    _descCtrl = TextEditingController(text: l?.description ?? '');
    _durCtrl = TextEditingController(text: (l?.durationMinutes ?? 10).toString());
    _tagsCtrl = TextEditingController(text: (l?.tags ?? []).join(', '));
    _selectedChapterId = l?.chapterId ?? (widget.chapters.isNotEmpty ? widget.chapters.first.id : '');
    _lessonNumber = l?.lessonNumber ?? widget.nextLessonNumber;
    _isPublished = l?.isPublished ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  List<String> _parseTags() {
    return _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Edit Lesson' : 'Create Lesson';
    return Dialog(
      insetPadding: EdgeInsets.all(context.scale(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: context.scale(600)),
        child: Padding(
          padding: EdgeInsets.all(context.scale(20)),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: context.scaleFont(20), fontWeight: FontWeight.bold)),
                  SizedBox(height: context.scale(16)),
                  TextFormField(
                    controller: _titleCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Title',
                      hintText: 'e.g., Understanding Road Signs',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Lesson title is required';
                      if (value.length > 60) return 'Keep it under 60 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: context.scale(12)),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'A short summary of the lesson',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  SizedBox(height: context.scale(12)),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedChapterId.isNotEmpty ? _selectedChapterId : null,
                    decoration: const InputDecoration(
                      labelText: 'Chapter',
                      hintText: 'Select a chapter…',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.chapters.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _selectedChapterId = v ?? ''),
                    validator: (v) => (v == null || v.isEmpty) ? 'Select a chapter' : null,
                  ),
                  SizedBox(height: context.scale(12)),
                  TextFormField(
                    controller: _durCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Duration (min)',
                      hintText: '10',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final val = int.tryParse(v ?? '');
                      if (val == null) return 'Enter a number';
                      if (val < 1) return 'At least 1 minute';
                      if (val > 120) return 'At most 120 minutes';
                      return null;
                    },
                  ),
                  SizedBox(height: context.scale(12)),
                  TextFormField(
                    controller: _tagsCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tags (optional)',
                      hintText: 'e.g., signs, traffic, safety',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: context.scale(12)),
                  SwitchListTile(
                    title: const Text('Publish immediately'),
                    subtitle: Text(
                      'Only published lessons are visible to users',
                      style: TextStyle(
                        fontSize: context.scaleFont(12),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _isPublished,
                    onChanged: (v) => setState(() => _isPublished = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SizedBox(height: context.scale(8)),
                  Text(
                    'XP is awarded from question points (set under Questions).',
                    style: TextStyle(
                      fontSize: context.scaleFont(12),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: context.scale(20)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      SizedBox(width: context.scale(12)),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = context.read<UserProvider>().user;
      final now = Timestamp.now();
      final lesson = Lesson(
        id: widget.lesson?.id ?? '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        chapterId: _selectedChapterId,
        lessonNumber: _lessonNumber,
        isPublished: _isPublished,
        durationMinutes: int.tryParse(_durCtrl.text) ?? 10,
        tags: _parseTags(),
        pointsAvailable: widget.lesson?.pointsAvailable ?? 0,
        createdAt: widget.lesson?.createdAt ?? now,
        createdBy: widget.lesson?.createdBy ?? user?.userId ?? '',
        updatedAt: now,
        updatedBy: user?.userId,
      );

      final service = LessonService.instance;
      if (_isEditing) {
        await service.updateLesson(lesson);
      } else {
        await service.createLesson(lesson);
      }

      if (!mounted) return;
      SnackbarUtils.showSuccess(context, _isEditing ? 'Lesson updated' : 'Lesson created');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
