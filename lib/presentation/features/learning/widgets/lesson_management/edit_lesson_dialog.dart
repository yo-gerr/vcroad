import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/question_editor.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';

class EditLessonDialog extends StatefulWidget {
  final QuizMaterial lesson;

  const EditLessonDialog({super.key, required this.lesson});

  @override
  State<EditLessonDialog> createState() => _EditLessonDialogState();
}

class _EditLessonDialogState extends State<EditLessonDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _chapterOrderCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _lessonNumberCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _tagsCtrl;

  late List<QuizQuestion> _questions;
  late bool _isPublished;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categoryCtrl = TextEditingController(text: widget.lesson.chapterCategory);
    _chapterOrderCtrl = TextEditingController(
      text: widget.lesson.chapterOrder.toString(),
    );
    _titleCtrl = TextEditingController(text: widget.lesson.title);
    _descriptionCtrl = TextEditingController(text: widget.lesson.description);
    _lessonNumberCtrl = TextEditingController(
      text: widget.lesson.lessonNumber?.toString() ?? '',
    );
    _durationCtrl = TextEditingController(
      text: widget.lesson.durationMinutes.toString(),
    );
    _tagsCtrl = TextEditingController(text: widget.lesson.tags.join(', '));
    _questions = List.from(widget.lesson.questions);
    _isPublished = widget.lesson.isPublished;
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _chapterOrderCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _lessonNumberCtrl.dispose();
    _durationCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
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
      SnackbarUtils.showWarning(context, 'Add at least one question');
      return;
    }

    // Validate all questions
    for (int i = 0; i < _questions.length; i++) {
      final validation = _questions[i].validate();
      if (!validation.isValid) {
        SnackbarUtils.showError(
          context,
          'Question ${i + 1}: ${validation.message ?? 'Invalid'}',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final updatedLesson = widget.lesson.copyWith(
      chapterCategory: _categoryCtrl.text.trim(),
      chapterOrder: int.tryParse(_chapterOrderCtrl.text) ?? 0,
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      questions: _questions,
      lessonNumber: int.tryParse(_lessonNumberCtrl.text),
      isPublished: _isPublished,
      durationMinutes: int.tryParse(_durationCtrl.text) ?? 10,
      tags: tags,
    );

    if (mounted) {
      Navigator.of(context).pop(updatedLesson);
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
                    Icons.edit,
                    size: info.scale(28),
                    color: const Color(0xFF001278),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: Text(
                      'Edit Lesson',
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

            // Content
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(info.scale(20)),
                  children: [
                    // Category
                    InputStyles.fieldLabel('Chapter Category'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: _categoryCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Chapter Category',
                        hint: 'e.g., Traffic Signs, Road Rules',
                      ),
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          validateRequired(v, fieldName: 'Chapter Category'),
                    ),
                    SizedBox(height: info.scale(16)),

                    // Chapter Order & Lesson Number Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InputStyles.fieldLabel('Chapter Order'),
                              SizedBox(height: info.scale(4)),
                              TextFormField(
                                controller: _chapterOrderCtrl,
                                decoration: InputStyles.decoration(
                                  label: 'Order',
                                  hint: '0',
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (v) => validateRequired(
                                  v,
                                  fieldName: 'Chapter Order',
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: info.scale(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InputStyles.fieldLabel('Lesson Number'),
                              SizedBox(height: info.scale(4)),
                              TextFormField(
                                controller: _lessonNumberCtrl,
                                decoration: InputStyles.decoration(
                                  label: 'Number',
                                  hint: '1',
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: info.scale(16)),

                    // Title
                    InputStyles.fieldLabel('Title'),
                    SizedBox(height: info.scale(4)),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputStyles.decoration(
                        label: 'Lesson Title',
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
                              InputStyles.fieldLabel('Duration (minutes)'),
                              SizedBox(height: info.scale(4)),
                              TextFormField(
                                controller: _durationCtrl,
                                decoration: InputStyles.decoration(
                                  label: 'Duration',
                                  hint: '10',
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (v) =>
                                    validateRequired(v, fieldName: 'Duration'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: info.scale(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InputStyles.fieldLabel('Status'),
                              SizedBox(height: info.scale(4)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: info.scale(12),
                                ),
                                decoration: BoxDecoration(
                                  color: InputStyles.inputFillColor,
                                  borderRadius: BorderRadius.circular(
                                    InputStyles.borderRadiusValue,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _isPublished ? 'Published' : 'Draft',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: _isPublished,
                                      onChanged: (v) =>
                                          setState(() => _isPublished = v),
                                      activeThumbColor: Colors.green,
                                    ),
                                  ],
                                ),
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
                        hint: 'safety, signs, rules',
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
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: info.scale(12),
                              vertical: info.scale(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: info.scale(12)),

                    // Questions List
                    if (_questions.isEmpty)
                      Container(
                        padding: EdgeInsets.all(info.scale(32)),
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
                              'No questions added yet',
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
                          final question = _questions[index];
                          return _QuestionTile(
                            key: ValueKey(question.id),
                            question: question,
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
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(info.scale(48)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: info.scale(20),
                              height: info.scale(20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Save Changes',
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
