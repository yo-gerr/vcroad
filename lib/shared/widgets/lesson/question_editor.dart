import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/question.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/lesson/question_editors/multiple_choice_editor.dart';
import 'package:vcroad_v2/shared/widgets/lesson/question_editors/true_false_editor.dart';
import 'package:vcroad_v2/shared/widgets/lesson/question_editors/identification_editor.dart';
import 'package:vcroad_v2/shared/widgets/lesson/question_editors/matching_type_editor.dart';

class QuestionEditorDialog extends StatefulWidget {
  final QuizQuestion? question;

  const QuestionEditorDialog({super.key, this.question});

  @override
  State<QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<QuestionEditorDialog> {
  late QuestionType _selectedType;
  QuizQuestion? _editedQuestion;

  // Inline feedback
  String? _inlineMessage;
  Color? _inlineMessageColor;
  Timer? _inlineMessageTimer;

  void _showInlineMessage(
    String message, {
    Color color = Colors.red,
    Duration duration = const Duration(seconds: 3),
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
  void dispose() {
    _inlineMessageTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedType = widget.question?.type ?? QuestionType.multipleChoice;
    _editedQuestion = widget.question;
  }

  void _handleTypeChange(QuestionType? type) {
    if (type == null || type == _selectedType) return;

    setState(() {
      _selectedType = type;
      _editedQuestion = null; // Reset question when type changes
    });
  }

  Widget _buildEditor() {
    switch (_selectedType) {
      case QuestionType.multipleChoice:
        return MultipleChoiceEditor(
          question: _editedQuestion,
          onQuestionChanged: (q) => _editedQuestion = q,
        );
      case QuestionType.trueFalse:
        return TrueFalseEditor(
          question: _editedQuestion,
          onQuestionChanged: (q) => _editedQuestion = q,
        );
      case QuestionType.identification:
        return IdentificationEditor(
          question: _editedQuestion,
          onQuestionChanged: (q) => _editedQuestion = q,
        );
      case QuestionType.matchingType:
        return MatchingTypeEditor(
          question: _editedQuestion,
          onQuestionChanged: (q) => _editedQuestion = q,
        );
    }
  }

  void _submit() {
    if (_editedQuestion != null) {
      final validation = _editedQuestion!.validate();
      if (!validation.isValid) {
        _showInlineMessage(
          validation.message ?? 'Invalid question',
          color: Colors.red,
        );
        return;
      }
      Navigator.of(context).pop(_editedQuestion);
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
                    Icons.quiz,
                    size: info.scale(28),
                    color: const Color(0xFF001278),
                  ),
                  SizedBox(width: info.scale(12)),
                  Expanded(
                    child: Text(
                      widget.question == null
                          ? 'Create Question'
                          : 'Edit Question',
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

            // Inline feedback (placed immediately after header so it's visible)
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

            // Type Selector
            Padding(
              padding: EdgeInsets.all(info.scale(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question Type',
                    style: TextStyle(
                      fontSize: info.scaleFont(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: info.scale(8)),
                  SegmentedButton<QuestionType>(
                    selected: {_selectedType},
                    onSelectionChanged: (Set<QuestionType> types) {
                      _handleTypeChange(types.first);
                    },
                    segments: QuestionType.values.map((type) {
                      return ButtonSegment<QuestionType>(
                        value: type,
                        label: Text(
                          type.displayName,
                          style: TextStyle(fontSize: info.scaleFont(11)),
                        ),
                        icon: Icon(
                          _getIconData(type.iconName),
                          size: info.scale(18),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Editor
            Expanded(child: _buildEditor()),

            const Divider(height: 1),

            // Actions
            Padding(
              padding: EdgeInsets.all(info.scale(20)),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(info.scale(48)),
                      ),
                      child: Text(
                        widget.question == null
                            ? 'Add Question'
                            : 'Save Changes',
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

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'radio_button_checked':
        return Icons.radio_button_checked;
      case 'check_circle':
        return Icons.check_circle;
      case 'edit':
        return Icons.edit;
      case 'compare_arrows':
        return Icons.compare_arrows;
      default:
        return Icons.help;
    }
  }
}
