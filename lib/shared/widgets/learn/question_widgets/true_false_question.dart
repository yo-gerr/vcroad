import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/models/question.dart';
import 'package:vcroad_v2/shared/providers/learning.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/format/text.dart';

class TrueFalseQuestion extends StatefulWidget {
  final QuizQuestion question;

  const TrueFalseQuestion({super.key, required this.question});

  @override
  State<TrueFalseQuestion> createState() => _TrueFalseQuestionState();
}

class _TrueFalseQuestionState extends State<TrueFalseQuestion> {
  bool? _selectedAnswer;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _isProcessing = false;

  Future<void> _submitAnswer() async {
    final provider = context.read<LearningProvider>();
    if (provider.isTimeExpired) return;
    if (_selectedAnswer == null) return;
    final isCorrect = await provider.submitAnswer(_selectedAnswer);
    if (!mounted) return;
    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
    });
  }

  Future<void> _nextQuestion() async {
    final provider = context.read<LearningProvider>();

    if (provider.currentQuestionIndex <
        provider.currentLesson!.questions.length - 1) {
      provider.nextQuestion();
      if (!mounted) return;
      setState(() {
        _selectedAnswer = null;
        _isAnswered = false;
        _isCorrect = null;
      });
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await provider.completeLesson();
    if (!mounted) return;
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question Card
        Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(info.scale(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(info.scale(8)),
                      decoration: BoxDecoration(
                        color: const Color(0xFF001278).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        color: const Color(0xFF001278),
                        size: info.scale(20),
                      ),
                    ),
                    SizedBox(width: info.scale(8)),
                    Expanded(
                      child: Text(
                        'True or False',
                        style: TextStyle(
                          fontSize: info.scaleFont(12),
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: info.scale(8),
                        vertical: info.scale(4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pointsLabel(widget.question.points),
                        style: TextStyle(
                          fontSize: info.scaleFont(11),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: info.scale(16)),
                Text(
                  widget.question.question,
                  style: TextStyle(
                    fontSize: info.scaleFont(16),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                if (widget.question.questionImage?.remoteUrl != null) ...[
                  SizedBox(height: info.scale(16)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.question.questionImage!.remoteUrl!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: (ctx, url) => SizedBox(
                        height: info.scale(120),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (ctx, url, err) => SizedBox(
                        height: info.scale(120),
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ] else if (widget.question.questionImage?.hasLocal ??
                    false) ...[
                  SizedBox(height: info.scale(16)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(
                      image: ResizeImage(
                        FileImage(
                          File(widget.question.questionImage!.localPath!),
                        ),
                        width: info.isMobile ? 800 : 1200,
                      ),
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: info.scale(24)),

        // True/False Buttons
        Row(
          children: [
            Expanded(
              child: _TrueFalseButton(
                label: 'TRUE',
                value: true,
                isSelected: _selectedAnswer == true,
                isCorrect: _isAnswered && widget.question.correctBool == true,
                isWrong:
                    _isAnswered &&
                    _selectedAnswer == true &&
                    widget.question.correctBool != true,
                isDisabled: _isAnswered || _isProcessing,
                onTap: _isAnswered || _isProcessing
                    ? null
                    : () => setState(() => _selectedAnswer = true),
              ),
            ),
            SizedBox(width: info.scale(16)),
            Expanded(
              child: _TrueFalseButton(
                label: 'FALSE',
                value: false,
                isSelected: _selectedAnswer == false,
                isCorrect: _isAnswered && widget.question.correctBool == false,
                isWrong:
                    _isAnswered &&
                    _selectedAnswer == false &&
                    widget.question.correctBool != false,
                isDisabled: _isAnswered || _isProcessing,
                onTap: _isAnswered || _isProcessing
                    ? null
                    : () => setState(() => _selectedAnswer = false),
              ),
            ),
          ],
        ),

        // Feedback
        if (_isAnswered) ...[
          SizedBox(height: info.scale(16)),
          Container(
            padding: EdgeInsets.all(info.scale(16)),
            decoration: BoxDecoration(
              color: (_isCorrect! ? Colors.green : Colors.red).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCorrect! ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isCorrect! ? Icons.check_circle : Icons.cancel,
                  color: _isCorrect! ? Colors.green : Colors.red,
                  size: info.scale(32),
                ),
                SizedBox(width: info.scale(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCorrect! ? 'Correct!' : 'Incorrect',
                        style: TextStyle(
                          fontSize: info.scaleFont(16),
                          fontWeight: FontWeight.bold,
                          color: _isCorrect! ? Colors.green : Colors.red,
                        ),
                      ),
                      if (widget.question.explanation != null) ...[
                        SizedBox(height: info.scale(4)),
                        Text(
                          widget.question.explanation!,
                          style: TextStyle(
                            fontSize: info.scaleFont(13),
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: info.scale(24)),

        // Action Button
        SizedBox(
          width: double.infinity,
          child: _isProcessing
              ? SizedBox(
                  height: info.scale(56),
                  child: const Center(child: CircularProgressIndicator()),
                )
              : ElevatedButton(
                  onPressed: _isAnswered
                      ? _nextQuestion
                      : ((_selectedAnswer != null &&
                                !context.read<LearningProvider>().isTimeExpired)
                            ? _submitAnswer
                            : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001278),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: info.scale(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isAnswered ? 'Continue' : 'Submit Answer',
                    style: TextStyle(
                      fontSize: info.scaleFont(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TrueFalseButton extends StatelessWidget {
  final String label;
  final bool value;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _TrueFalseButton({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.isCorrect,
    required this.isWrong,
    required this.isDisabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    Color borderColor;
    Color backgroundColor;
    Color textColor;

    if (isCorrect) {
      borderColor = Colors.green;
      backgroundColor = Colors.green;
      textColor = Colors.white;
    } else if (isWrong) {
      borderColor = Colors.red;
      backgroundColor = Colors.red;
      textColor = Colors.white;
    } else if (isSelected) {
      borderColor = const Color(0xFF001278);
      backgroundColor = const Color(0xFF001278);
      textColor = Colors.white;
    } else {
      borderColor = Colors.grey[300]!;
      backgroundColor = Colors.white;
      textColor = Colors.grey[700]!;
    }

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: info.scale(32)),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle
                    : isWrong
                    ? Icons.cancel
                    : (value ? Icons.check : Icons.close),
                color: textColor,
                size: info.scale(48),
              ),
              SizedBox(height: info.scale(12)),
              Text(
                label,
                style: TextStyle(
                  fontSize: info.scaleFont(20),
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
