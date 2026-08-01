import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/data/repositories/lesson.dart';
import 'package:vcroad/data/repositories/lesson_progress.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/presentation/features/lesson/screens/lesson_result_screen.dart';
import 'package:vcroad/presentation/features/lesson/widgets/question_display_widget.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final LessonService _service = LessonService.instance;
  final LessonProgressService _progressService = LessonProgressService.instance;

  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  int _correctCount = 0;

  final Map<int, dynamic> _answers = {};
  final Map<int, bool> _results = {};

  int _elapsedSeconds = 0;
  Timer? _timer;

  bool get _isLastQuestion => _currentIndex >= _questions.length - 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final qs = await _service.getQuestions(widget.lesson.id);
    if (!mounted) return;
    setState(() {
      _questions = qs;
      _loading = false;
    });
    _startLesson();
  }

  Future<void> _startLesson() async {
    final userId = context.read<UserProvider>().user?.userId;
    if (userId == null) return;
    await _progressService.startLesson(userId, widget.lesson.id);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _submitAnswer() async {
    final userId = context.read<UserProvider>().user?.userId;
    if (userId == null) return;

    final q = _questions[_currentIndex];
    final userAnswer = _answers[_currentIndex];
    if (userAnswer == null) return;

    setState(() => _submitting = true);

    final isCorrect = _checkAnswer(q, userAnswer);

    await _progressService.submitAnswer(
      userId: userId,
      lessonId: widget.lesson.id,
      question: q,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
    );

    setState(() {
      _submitting = false;
      _showFeedback = true;
      _lastAnswerCorrect = isCorrect;
      _results[_currentIndex] = isCorrect;
      if (isCorrect) {
        _correctCount++;
      }
    });
  }

  bool _checkAnswer(QuizQuestion q, dynamic answer) {
    switch (q.type) {
      case QuestionType.multipleChoice:
        return answer == q.correctIndex;
      case QuestionType.trueFalse:
        return answer == q.correctBool;
      case QuestionType.identification:
        final normalized = (answer as String?)?.trim().toLowerCase() ?? '';
        final correct = q.correctAnswer?.trim().toLowerCase() ?? '';
        return normalized == correct;
      case QuestionType.matchingType:
        final userMap = answer is Map ? Map<String, String>.from(answer) : <String, String>{};
        final pairs = q.matchingPairs ?? [];
        if (userMap.length != pairs.length) return false;
        for (final p in pairs) {
          if (userMap[p.id]?.trim().toLowerCase() != p.meaning.trim().toLowerCase()) {
            return false;
          }
        }
        return true;
    }
  }

  void _goNext() {
    if (_isLastQuestion) {
      _finishLesson();
    } else {
      setState(() {
        _currentIndex++;
        _showFeedback = false;
      });
    }
  }

  Future<void> _finishLesson() async {
    _timer?.cancel();
    final userId = context.read<UserProvider>().user?.userId;
    if (userId == null) return;

    final result = await _progressService.completeLesson(userId, widget.lesson.id);
    if (!mounted) return;

    result['questionsCorrect'] = _correctCount;
    result['questionsAnswered'] = _questions.length;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LessonResultScreen(
          result: result,
          lessonTitle: widget.lesson.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Leave Lesson?'),
              content: const Text('Your progress will be saved.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
                ElevatedButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Leave', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.lesson.title, style: TextStyle(color: Colors.white, fontSize: context.scaleFont(16))),
            Text(
              '${_currentIndex + 1} of ${_questions.length}',
              style: TextStyle(color: Colors.white70, fontSize: context.scaleFont(12)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.scale(12)),
            child: Center(
              child: Text(
                '${_elapsedSeconds ~/ 60}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.white, fontSize: context.scaleFont(16), fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
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
                      Text('No questions in this lesson', style: TextStyle(fontSize: context.scaleFont(18), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_showFeedback)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.scale(12)),
                        color: _lastAnswerCorrect ? Colors.green.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08),
                        child: Row(
                          children: [
                            Icon(
                              _lastAnswerCorrect ? Icons.check_circle : Icons.cancel,
                              color: _lastAnswerCorrect ? Colors.green : Colors.red,
                              size: context.scale(22),
                            ),
                            SizedBox(width: context.scale(8)),
                            Expanded(
                              child: Text(
                                _lastAnswerCorrect ? 'Correct!' : 'Incorrect',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.scaleFont(15),
                                  color: _lastAnswerCorrect ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                            Text(
                              '+${_questions[_currentIndex].points} pts',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.scaleFont(14), color: AppColors.primaryAdaptive(context)),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: PageView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        controller: PageController(initialPage: _currentIndex),
                        onPageChanged: (i) {
                          setState(() {
                            _currentIndex = i;
                            _showFeedback = false;
                          });
                        },
                        itemBuilder: (_, i) {
                          if (i != _currentIndex) return const SizedBox.shrink();
                          return QuestionDisplayWidget(
                            question: _questions[i],
                            currentAnswer: _answers[i],
                            onAnswerChanged: (v) => _answers[i] = v,
                          );
                        },
                      ),
                    ),
                    if (_showFeedback && _questions[_currentIndex].explanation != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.scale(12)),
                        color: Theme.of(context).cardColor,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, size: context.scale(18), color: Colors.blue.shade700),
                            SizedBox(width: context.scale(8)),
                            Expanded(
                              child: Text(
                                _questions[_currentIndex].explanation!,
                                style: TextStyle(fontSize: context.scaleFont(13), color: Colors.blue.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildBottomBar(context),
                  ],
                ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting
                ? null
                : _showFeedback
                    ? _goNext
                    : (_answers[_currentIndex] != null ? _submitAnswer : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showFeedback ? Theme.of(context).colorScheme.primary : (_answers[_currentIndex] != null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
              padding: EdgeInsets.symmetric(vertical: context.scale(14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _showFeedback ? (_isLastQuestion ? 'Finish' : 'Next') : 'Submit',
                    style: TextStyle(color: _answers[_currentIndex] != null || _showFeedback ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: context.scaleFont(16), fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}
