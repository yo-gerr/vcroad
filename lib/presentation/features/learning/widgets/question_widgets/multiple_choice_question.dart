import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/presentation/providers/learning.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/format/text.dart';

class MultipleChoiceQuestion extends StatefulWidget {
  final QuizQuestion question;

  const MultipleChoiceQuestion({super.key, required this.question});

  @override
  State<MultipleChoiceQuestion> createState() => _MultipleChoiceQuestionState();
}

class _MultipleChoiceQuestionState extends State<MultipleChoiceQuestion> {
  int? _selectedIndex;
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _isProcessing = false;

  Future<void> _submitAnswer() async {
    if (_selectedIndex == null) return;
    final provider = context.read<LearningProvider>();
    if (provider.isTimeExpired) return;
    final isCorrect = await provider.submitAnswer(_selectedIndex);
    if (!mounted) return;
    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
    });
  }

  Future<void> _nextQuestion() async {
    final provider = context.read<LearningProvider>();

    // not last question -> go next
    if (provider.currentQuestionIndex <
        provider.currentLesson!.questions.length - 1) {
      provider.nextQuestion();
      if (!mounted) return;
      setState(() {
        _selectedIndex = null;
        _isAnswered = false;
        _isCorrect = null;
      });
      return;
    }

    // last question -> complete lesson (prevent double taps)
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
                        Icons.quiz,
                        color: const Color(0xFF001278),
                        size: info.scale(20),
                      ),
                    ),
                    SizedBox(width: info.scale(8)),
                    Expanded(
                      child: Text(
                        'Multiple Choice',
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
        SizedBox(height: info.scale(16)),

        // Options
        ...List.generate(widget.question.options!.length, (index) {
          final option = widget.question.options![index];
          final optionImage = widget.question.optionImages?[index];
          final isSelected = _selectedIndex == index;
          final isCorrectAnswer = widget.question.correctIndex == index;
          final showCorrect = _isAnswered && isCorrectAnswer;
          final showWrong = _isAnswered && isSelected && !isCorrectAnswer;

          return Padding(
            padding: EdgeInsets.only(bottom: info.scale(12)),
            child: _OptionCard(
              option: option,
              optionImage: optionImage,
              isSelected: isSelected,
              isCorrect: showCorrect,
              isWrong: showWrong,
              isDisabled: _isAnswered || _isProcessing,
              onTap: _isAnswered || _isProcessing
                  ? null
                  : () => setState(() => _selectedIndex = index),
            ),
          );
        }),

        // Feedback
        if (_isAnswered) ...[
          SizedBox(height: info.scale(16)),
          Container(
            padding: EdgeInsets.all(info.scale(16)),
            decoration: BoxDecoration(
              color: (_isCorrect! ? Colors.green : Colors.red).withValues(
                alpha: .1,
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

        // Action Button / Processing
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
                      : ((_selectedIndex != null &&
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

class _OptionCard extends StatelessWidget {
  final String option;
  final ImageRef? optionImage;
  final bool isSelected;
  final bool isCorrect;
  final bool isWrong;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.option,
    this.optionImage,
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

    if (isCorrect) {
      borderColor = Colors.green;
      backgroundColor = Colors.green.withValues(alpha: 0.1);
    } else if (isWrong) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.1);
    } else if (isSelected) {
      borderColor = const Color(0xFF001278);
      backgroundColor = const Color(0xFF001278).withValues(alpha: 0.05);
    } else {
      borderColor = Colors.grey[300]!;
      backgroundColor = Colors.white;
    }

    return Card(
      elevation: isSelected ? 4 : 1,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(info.scale(16)),
          child: Row(
            children: [
              // Radio visual
              Container(
                width: info.scale(24),
                height: info.scale(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                  color: (isSelected || isCorrect || isWrong)
                      ? borderColor
                      : Colors.transparent,
                ),
                child: (isCorrect || isWrong)
                    ? Icon(
                        isCorrect ? Icons.check : Icons.close,
                        size: info.scale(16),
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: info.scale(12)),

              // Option Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (optionImage?.remoteUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: optionImage!.remoteUrl!,
                          height: info.scale(100),
                          width: double.infinity,
                          fit: BoxFit.contain,
                          placeholder: (ctx, url) => SizedBox(
                            height: info.scale(100),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (ctx, url, err) => SizedBox(
                            height: info.scale(100),
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: info.scale(8)),
                    ] else if (optionImage?.hasLocal ?? false) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image(
                          image: ResizeImage(
                            FileImage(File(optionImage!.localPath!)),
                            width: info.isMobile ? 800 : 1200,
                          ),
                          height: info.scale(100),
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(height: info.scale(8)),
                    ],
                    Text(
                      option,
                      style: TextStyle(
                        fontSize: info.scaleFont(14),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
