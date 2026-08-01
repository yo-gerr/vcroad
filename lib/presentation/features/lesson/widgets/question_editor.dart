import 'package:flutter/material.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/data/repositories/lesson.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/features/lesson/widgets/question_widgets.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class QuestionEditor extends StatefulWidget {
  final Lesson lesson;

  const QuestionEditor({super.key, required this.lesson});

  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  final LessonService _service = LessonService.instance;
  List<QuizQuestion> _questions = [];
  bool _loading = true;
  bool _saving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final qs = await _service.getQuestions(widget.lesson.id);
    if (!mounted) return;
    setState(() {
      _questions = qs;
      _loading = false;
    });
  }

  Future<void> _addQuestion() async {
    final type = await showModalBottomSheet<QuestionType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: QuestionType.values.map((t) => ListTile(
            leading: Icon(_typeIcon(t), color: AppColors.primaryAdaptive(context)),
            title: Text(t.displayName),
            onTap: () => Navigator.pop(ctx, t),
          )).toList(),
        ),
      ),
    );
    if (type == null || !mounted) return;

    final q = await showDialog<QuizQuestion>(
      context: context,
      builder: (_) => QuestionEditDialog(
        lessonId: widget.lesson.id,
        order: _questions.length,
      ),
    );
    if (q != null) {
      setState(() {
        _questions.add(q);
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _editQuestion(int index) async {
    final q = await showDialog<QuizQuestion>(
      context: context,
      builder: (_) => QuestionEditDialog(
        question: _questions[index],
        lessonId: widget.lesson.id,
        order: index,
      ),
    );
    if (q != null) {
      setState(() {
        _questions[index] = q;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _deleteQuestion(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Remove this question?'),
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
    if (confirm == true) {
      setState(() {
        _questions.removeAt(index);
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_saving) return false;
    if (!_hasUnsavedChanges) return true;

    final choice = await showDialog<_ExitChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DiscardChangesDialog(),
    );

    switch (choice) {
      case _ExitChoice.discard:
        return true;
      case _ExitChoice.saveAndExit:
        return await _performSave();
      case _ExitChoice.keepEditing:
      case null:
        return false;
    }
  }

  Future<bool> _performSave() async {
    final invalid = _questions.where((q) => !q.validate().isValid).toList();
    if (invalid.isNotEmpty) {
      final first = invalid.first.validate();
      SnackbarUtils.showError(
        context,
        first.message ?? '${invalid.length} question(s) have validation errors',
      );
      return false;
    }

    setState(() => _saving = true);
    try {
      final qs = _questions.asMap().entries.map((e) => e.value.copyWith(order: e.key)).toList();
      await _service.saveQuestions(lessonId: widget.lesson.id, questions: qs);
      if (!mounted) return false;
      SnackbarUtils.showSuccess(context, 'Questions saved');
      _hasUnsavedChanges = false;
      return true;
    } catch (e) {
      if (!mounted) return false;
      SnackbarUtils.showError(context, 'Error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.pop(this.context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          centerTitle: true,
          title: Text('Questions: ${widget.lesson.title}', style: TextStyle(color: Colors.white, fontSize: context.scaleFont(16)), overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(
              onPressed: _loading || _saving
                  ? null
                  : () async {
                      final saved = await _performSave();
                      if (saved && mounted) Navigator.pop(this.context);
                    },
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_add_question',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Question'),
          onPressed: _addQuestion,
        ),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_outlined, size: context.scale(64), color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(height: context.scale(16)),
                      Text('No questions yet', style: TextStyle(fontSize: context.scaleFont(18), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      SizedBox(height: context.scale(8)),
                      Text('Tap "Add Question" to begin', style: TextStyle(fontSize: context.scaleFont(14), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: _questions.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _questions.removeAt(oldIndex);
                      _questions.insert(newIndex, item);
                      _hasUnsavedChanges = true;
                    });
                  },
                  itemBuilder: (_, i) {
                    final q = _questions[i];
                    return Card(
                      key: ValueKey(q.id),
                      margin: EdgeInsets.symmetric(horizontal: context.scale(16), vertical: context.scale(4)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          radius: context.scale(14),
                          child: Text('${i + 1}', style: TextStyle(fontSize: context.scaleFont(12), fontWeight: FontWeight.bold, color: AppColors.primaryAdaptive(context))),
                        ),
                        title: buildQuestionPreview(q, context),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editQuestion(i)),
                            IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteQuestion(i)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }

  IconData _typeIcon(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice: return Icons.checklist;
      case QuestionType.trueFalse: return Icons.toggle_on;
      case QuestionType.identification: return Icons.short_text;
      case QuestionType.matchingType: return Icons.compare_arrows;
    }
  }
}

enum _ExitChoice { discard, saveAndExit, keepEditing }

class _DiscardChangesDialog extends StatelessWidget {
  const _DiscardChangesDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.responsive.isMobile ? 16 : (MediaQuery.of(context).size.width - 360) / 2,
        vertical: context.scale(24),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: EdgeInsets.all(context.scale(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Discard changes?',
                style: TextStyle(fontSize: context.scaleFont(18), fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.scale(16)),
              Text(
                'You have unsaved question edits. Leaving now will lose your changes.',
                style: TextStyle(fontSize: context.scaleFont(14)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.scale(24)),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(_ExitChoice.keepEditing),
                  child: const Text('Keep editing'),
                ),
              ),
              SizedBox(height: context.scale(8)),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(_ExitChoice.discard),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Discard'),
                ),
              ),
              SizedBox(height: context.scale(8)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_ExitChoice.saveAndExit),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Save & Exit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
