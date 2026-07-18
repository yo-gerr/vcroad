import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/presentation/providers/learning.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/utils/format/text.dart';

class IdentificationQuestion extends StatefulWidget {
  final QuizQuestion question;

  const IdentificationQuestion({super.key, required this.question});

  @override
  State<IdentificationQuestion> createState() => _IdentificationQuestionState();
}

class _IdentificationQuestionState extends State<IdentificationQuestion> {
  final _controller = TextEditingController();
  bool _isAnswered = false;
  bool? _isCorrect;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Listen so typing updates the UI (enables/disables button)
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!mounted) return;
    // Only update minimal state: triggers rebuild so the button state updates
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final provider = context.read<LearningProvider>();
    if (provider.isTimeExpired) return;
    if (_controller.text.trim().isEmpty) return;
    final isCorrect = await provider.submitAnswer(_controller.text);
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
        _controller.clear();
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
                        Icons.edit_note,
                        color: const Color(0xFF001278),
                        size: info.scale(20),
                      ),
                    ),
                    SizedBox(width: info.scale(8)),
                    Expanded(
                      child: Text(
                        'Identification',
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

        // Answer Input
        Card(
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(info.scale(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Answer',
                  style: TextStyle(
                    fontSize: info.scaleFont(14),
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: info.scale(8)),
                TextField(
                  controller: _controller,
                  enabled: !_isAnswered && !_isProcessing,
                  decoration: InputDecoration(
                    hintText: 'Type your answer here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: _isAnswered ? Colors.grey[100] : Colors.white,
                  ),
                  style: TextStyle(fontSize: info.scaleFont(14)),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                SizedBox(height: info.scale(8)),
                Text(
                  'Note: Answer is case-insensitive',
                  style: TextStyle(
                    fontSize: info.scaleFont(11),
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCorrect! ? Icons.check_circle : Icons.cancel,
                      color: _isCorrect! ? Colors.green : Colors.red,
                      size: info.scale(32),
                    ),
                    SizedBox(width: info.scale(12)),
                    Expanded(
                      child: Text(
                        _isCorrect! ? 'Correct!' : 'Incorrect',
                        style: TextStyle(
                          fontSize: info.scaleFont(16),
                          fontWeight: FontWeight.bold,
                          color: _isCorrect! ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_isCorrect!) ...[
                  SizedBox(height: info.scale(12)),
                  Container(
                    padding: EdgeInsets.all(info.scale(12)),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Correct Answer:',
                          style: TextStyle(
                            fontSize: info.scaleFont(12),
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: info.scale(4)),
                        Text(
                          widget.question.correctAnswer ?? '',
                          style: TextStyle(
                            fontSize: info.scaleFont(14),
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.question.explanation != null) ...[
                  SizedBox(height: info.scale(12)),
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

        SizedBox(height: info.scale(24)),

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
                      : ((_controller.text.trim().isNotEmpty &&
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
