import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/presentation/providers/lesson.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/question_editor.dart';

class CreateLessonDialog extends StatefulWidget {
  const CreateLessonDialog({super.key});

  @override
  State<CreateLessonDialog> createState() => _CreateLessonDialogState();
}

class _CreateLessonDialogState extends State<CreateLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _categoryCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  final List<QuizQuestion> _questions = [];
  bool _isPublished = false;
  bool _isLoading = false;

  // Chapter management
  List<ChapterInfo> _existingChapters = [];
  bool _isCreatingNewChapter = false;
  ChapterMetadata? _chapterMetadata;
  bool _isLoadingMetadata = false;

  // Inline feedback (replace snackbars inside dialog)
  String? _inlineMessage;
  Color? _inlineMessageColor;
  Timer? _inlineMessageTimer;

  void _showInlineMessage(
    String message, {
    Color color = Colors.red,
    Duration duration = const Duration(seconds: 4),
  }) {
    _inlineMessageTimer?.cancel();
    setState(() {
      _inlineMessage = message;
      _inlineMessageColor = color;
    });
    _inlineMessageTimer = Timer(duration, () {
      if (mounted) setState(() => _inlineMessage = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadChapterInfo();
    _categoryCtrl.addListener(_onCategoryChanged);
  }

  @override
  void dispose() {
    _inlineMessageTimer?.cancel();
    _categoryCtrl.removeListener(_onCategoryChanged);
    _categoryCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _durationCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChapterInfo() async {
    if (!mounted) return;

    setState(() => _isLoadingMetadata = true);

    try {
      final chapters = await context
          .read<LessonProvider>()
          .getChapterInfoList();
      if (mounted) {
        setState(() {
          _existingChapters = chapters;
          _isLoadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMetadata = false);
        _showInlineMessage('Failed to load chapters: $e', color: Colors.orange);
      }
    }
  }

  Future<void> _onCategoryChanged() async {
    final text = _categoryCtrl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _chapterMetadata = null;
        _isCreatingNewChapter = false;
      });
      return;
    }

    // Check if it matches an existing chapter
    final existing = _existingChapters
        .where((ch) => ch.category.toLowerCase() == text.toLowerCase())
        .firstOrNull;

    if (existing != null) {
      setState(() {
        _isCreatingNewChapter = false;
      });
    } else {
      setState(() {
        _isCreatingNewChapter = true;
      });
    }

    // Fetch metadata
    setState(() => _isLoadingMetadata = true);

    try {
      final metadata = await context.read<LessonProvider>().getChapterMetadata(
        text,
      );
      if (mounted && _categoryCtrl.text.trim() == text) {
        setState(() {
          _chapterMetadata = metadata;
          _isLoadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMetadata = false);
        // show inline non-blocking message
        _showInlineMessage(
          'Failed to fetch chapter metadata',
          color: Colors.orange,
        );
      }
    }
  }

  Future<void> _addQuestion() async {
    final question = await showDialog<QuizQuestion>(
      context: context,
      builder: (_) => const QuestionEditorDialog(),
    );

    if (question != null) {
      setState(() => _questions.add(question));
    }
  }

  Future<void> _editQuestion(int index) async {
    final question = await showDialog<QuizQuestion>(
      context: context,
      builder: (_) => QuestionEditorDialog(question: _questions[index]),
    );

    if (question != null) {
      setState(() => _questions[index] = question);
    }
  }

  void _deleteQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  void _reorderQuestions(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, item);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_questions.isEmpty) {
      _showInlineMessage('Add at least one question', color: Colors.red);
      return;
    }

    // Validate all questions
    for (int i = 0; i < _questions.length; i++) {
      final validation = _questions[i].validate();
      if (!validation.isValid) {
        _showInlineMessage(
          'Question ${i + 1}: ${validation.message}',
          color: Colors.red,
        );
        return;
      }
    }

    // Ensure we have chapter metadata
    if (_chapterMetadata == null) {
      _showInlineMessage(
        'Loading chapter information...',
        color: Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        _showInlineMessage('User not authenticated', color: Colors.red);
      }
      setState(() => _isLoading = false);
      return;
    }

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final lesson = QuizMaterial(
      id: '',
      chapterCategory: _categoryCtrl.text.trim(),
      chapterOrder: _chapterMetadata!.chapterOrder,
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      questions: _questions,
      lessonNumber: _chapterMetadata!.nextLessonNumber,
      createdAt: Timestamp.now(),
      createdBy: currentUser.uid,
      isPublished: _isPublished,
      durationMinutes: int.tryParse(_durationCtrl.text) ?? 10,
      tags: tags,
    );

    if (mounted) {
      Navigator.of(context).pop(lesson);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: info.isDesktop ? 700 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(info.scale(20)),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle,
                    size: info.scale(28),
                    color: const Color(0xFF001278),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: Text(
                      'Create New Lesson',
                      style: TextStyle(
                        fontSize: info.scaleFont(20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Inline feedback area (visible immediately under header)
            if (_inlineMessage != null)
              Container(
                width: double.infinity,
                color:
                    _inlineMessageColor?.withValues(alpha: 0.12) ??
                    Colors.red.withValues(alpha: 0.12),
                padding: EdgeInsets.symmetric(
                  horizontal: info.scale(16),
                  vertical: info.scale(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: _inlineMessageColor ?? Colors.red,
                      size: info.scale(18),
                    ),
                    SizedBox(width: info.scale(8)),
                    Expanded(
                      child: Text(
                        _inlineMessage!,
                        style: TextStyle(
                          color: _inlineMessageColor ?? Colors.red,
                          fontSize: info.scaleFont(13),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: info.scale(18)),
                      color: _inlineMessageColor ?? Colors.red,
                      onPressed: () {
                        _inlineMessageTimer?.cancel();
                        setState(() => _inlineMessage = null);
                      },
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(info.scale(20)),
                  children: [
                    // Category Selection with Autocomplete
                    InputStyles.fieldLabel('Chapter Category'),
                    SizedBox(height: info.scale(4)),
                    Autocomplete<ChapterInfo>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _existingChapters;
                        }
                        return _existingChapters.where((chapter) {
                          return chapter.category.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                        });
                      },
                      displayStringForOption: (ChapterInfo option) =>
                          option.category,
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                            // Sync with our controller
                            _categoryCtrl.text = controller.text;

                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputStyles.decoration(
                                label: 'Chapter Category',
                                hint: 'Select existing or type new category',
                                suffixIcon: _isLoadingMetadata
                                    ? Padding(
                                        padding: EdgeInsets.all(info.scale(12)),
                                        child: SizedBox(
                                          width: info.scale(16),
                                          height: info.scale(16),
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                        ),
                                      )
                                    : null,
                              ),
                              style: const TextStyle(color: Colors.white),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => validateRequired(
                                v,
                                fieldName: 'Chapter Category',
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: info.scale(200),
                                maxWidth: info.scale(300),
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    title: Text(option.category),
                                    subtitle: Text(
                                      '${option.lessonCount} lessons • Order: ${option.chapterOrder}',
                                      style: TextStyle(
                                        fontSize: info.scaleFont(11),
                                      ),
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      onSelected: (ChapterInfo selection) {
                        _categoryCtrl.text = selection.category;
                        setState(() {
                          _isCreatingNewChapter = false;
                        });
                      },
                    ),
                    SizedBox(height: info.scale(8)),

                    // Chapter Info Display
                    if (_chapterMetadata != null)
                      Container(
                        padding: EdgeInsets.all(info.scale(12)),
                        decoration: BoxDecoration(
                          color: _isCreatingNewChapter
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isCreatingNewChapter
                                ? Colors.blue
                                : Colors.green,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isCreatingNewChapter
                                  ? Icons.add_circle
                                  : Icons.check_circle,
                              color: _isCreatingNewChapter
                                  ? Colors.blue
                                  : Colors.green,
                              size: info.scale(20),
                            ),
                            SizedBox(width: info.scale(8)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isCreatingNewChapter
                                        ? 'Creating new chapter'
                                        : 'Adding to existing chapter',
                                    style: TextStyle(
                                      fontSize: info.scaleFont(12),
                                      fontWeight: FontWeight.w600,
                                      color: _isCreatingNewChapter
                                          ? Colors.blue[900]
                                          : Colors.green[900],
                                    ),
                                  ),
                                  SizedBox(height: info.scale(4)),
                                  Text(
                                    'Chapter Order: ${_chapterMetadata!.chapterOrder} • '
                                    'Lesson Number: ${_chapterMetadata!.nextLessonNumber}',
                                    style: TextStyle(
                                      fontSize: info.scaleFont(11),
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: info.scale(16)),

                    // Title
                    InputStyles.fieldLabel('Title'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Title',
                        hint: 'Enter lesson title',
                      ),
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (v) => validateRequired(v, fieldName: 'Title'),
                    ),
                    SizedBox(height: info.scale(16)),

                    // Description
                    InputStyles.fieldLabel('Description'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: _descriptionCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Description',
                        hint: 'Describe what this lesson covers',
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          validateRequired(v, fieldName: 'Description'),
                    ),
                    SizedBox(height: info.scale(16)),

                    // Duration & Published Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InputStyles.fieldLabel('Duration (min)'),
                              SizedBox(height: info.scale(4)),
                              TextFormField(
                                controller: _durationCtrl,
                                decoration: InputStyles.decoration(
                                  label: 'Minutes',
                                  hint: '10',
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: info.scale(16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InputStyles.fieldLabel('Publish Status'),
                              SizedBox(height: info.scale(4)),
                              SwitchListTile(
                                value: _isPublished,
                                onChanged: (val) =>
                                    setState(() => _isPublished = val),
                                title: Text(
                                  _isPublished ? 'Published' : 'Draft',
                                  style: TextStyle(
                                    fontSize: info.scaleFont(14),
                                  ),
                                ),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: info.scale(16)),

                    // Tags
                    InputStyles.fieldLabel('Tags (comma-separated)'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: _tagsCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Tags',
                        hint: 'traffic, signs, rules',
                      ),
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.done,
                    ),
                    SizedBox(height: info.scale(24)),

                    // Questions Section
                    Row(
                      children: [
                        Text(
                          'Questions (${_questions.length})',
                          style: TextStyle(
                            fontSize: info.scaleFont(16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _addQuestion,
                          icon: Icon(Icons.add, size: info.scale(18)),
                          label: const Text('Add Question'),
                        ),
                      ],
                    ),
                    SizedBox(height: info.scale(12)),

                    // Questions List
                    if (_questions.isEmpty)
                      Container(
                        padding: EdgeInsets.all(info.scale(24)),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.quiz_outlined,
                              size: info.scale(48),
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: info.scale(12)),
                            Text(
                              'No questions yet',
                              style: TextStyle(
                                fontSize: info.scaleFont(14),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        onReorderItem: _reorderQuestions,
                        itemBuilder: (context, index) {
                          return _QuestionTile(
                            key: ValueKey(_questions[index].id),
                            question: _questions[index],
                            index: index,
                            onEdit: () => _editQuestion(index),
                            onDelete: () => _deleteQuestion(index),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Actions
            Padding(
              padding: EdgeInsets.all(info.scale(20)),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(info.scale(48)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: info.scaleFont(14)),
                      ),
                    ),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || _isLoadingMetadata
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(info.scale(48)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: info.scale(20),
                              width: info.scale(20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Create Lesson',
                              style: TextStyle(fontSize: info.scaleFont(14)),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final QuizQuestion question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionTile({
    super.key,
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Card(
      margin: EdgeInsets.only(bottom: info.scale(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF001278),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          question.question.isEmpty
              ? '${question.type.displayName} Question'
              : question.question,
          style: TextStyle(
            fontSize: info.scaleFont(14),
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          question.type.displayName,
          style: TextStyle(
            fontSize: info.scaleFont(12),
            color: Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, size: info.scale(20)),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete, size: info.scale(20), color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
            Icon(
              Icons.drag_handle,
              size: info.scale(24),
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
