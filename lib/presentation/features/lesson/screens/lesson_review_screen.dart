import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/data/repositories/lesson_progress.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/presentation/features/lesson/screens/review_result_screen.dart';
import 'package:vcroad/presentation/features/lesson/widgets/question_display_widget.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/core/theme/app_colors.dart';

class LessonReviewScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonReviewScreen({super.key, required this.lesson});

  @override
  State<LessonReviewScreen> createState() => _LessonReviewScreenState();
}

class _LessonReviewScreenState extends State<LessonReviewScreen> {
  final LessonProgressService _progressService = LessonProgressService.instance;

  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  int _correctCount = 0;
  DateTime? _nextReviewAt;

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
    final userId = context.read<UserProvider>().user?.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final qs = await _progressService.getDueReviewQuestions(
      userId,
      widget.lesson.id,
    );
    final progress = await _progressService.getLessonProgress(
      userId,
      widget.lesson.id,
    );
    if (!mounted) return;
    setState(() {
      _questions = qs;
      _nextReviewAt = progress?.nextReviewAt;
      _loading = false;
    });
    if (_questions.isEmpty) return;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _startReviewAll() async {
    final userId = context.read<UserProvider>().user?.userId;
    if (userId == null) return;

    setState(() => _loading = true);
    final qs = await _progressService.getDueReviewQuestions(
      userId,
      widget.lesson.id,
      onlyDue: false,
    );
    if (!mounted) return;
    setState(() {
      _questions = qs;
      _currentIndex = 0;
      _correctCount = 0;
      _answers.clear();
      _results.clear();
      _showFeedback = false;
      _loading = false;
    });
    if (_questions.isEmpty) return;
    _startTimer();
  }

  void _submitAnswer() async {
    final userId = context.read<UserProvider>().user?.userId;
    if (userId == null) return;

    final q = _questions[_currentIndex];
    final userAnswer = _answers[_currentIndex];
    if (userAnswer == null) return;

    setState(() => _submitting = true);

    final isCorrect = _checkAnswer(q, userAnswer);

    await _progressService.submitReviewAnswer(
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
      if (isCorrect) _correctCount++;
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
        final userMap = answer is Map
            ? Map<String, String>.from(answer)
            : <String, String>{};
        final pairs = q.matchingPairs ?? [];
        if (userMap.length != pairs.length) return false;
        for (final p in pairs) {
          if (userMap[p.id]?.trim().toLowerCase() !=
              p.meaning.trim().toLowerCase()) {
            return false;
          }
        }
        return true;
    }
  }

  void _goNext() {
    if (_isLastQuestion) {
      _finishReview();
    } else {
      setState(() {
        _currentIndex++;
        _showFeedback = false;
      });
    }
  }

  Future<void> _finishReview() async {
    _timer?.cancel();
    final userId = context.read<UserProvider>().user?.userId;
    if (userId == null) return;

    final result = await _progressService.completeReview(
      userId,
      widget.lesson.id,
    );
    if (!mounted) return;

    result['questionsCorrect'] = _correctCount;
    result['questionsAnswered'] = _questions.length;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewResultScreen(
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
              title: const Text('Exit Review?'),
              content: const Text('Your progress will be saved.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Stay'),
                ),
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
            Text(
              'Review — ${widget.lesson.title}',
              style: TextStyle(color: Colors.white, fontSize: context.scaleFont(16)),
            ),
            Text(
              '${_questions.isEmpty ? 0 : _currentIndex + 1} of ${_questions.length}',
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
              ? _buildNothingDue(context)
              : Column(
                  children: [
                    if (_showFeedback)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.scale(12)),
                        color: _lastAnswerCorrect
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.red.withValues(alpha: 0.08),
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
                                  color: _lastAnswerCorrect
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                            Text(
                              '+${_questions[_currentIndex].points} pts',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: context.scaleFont(14),
                                color: AppColors.primaryAdaptive(context),
                              ),
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
                        color: AppColors.primary,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, size: context.scale(18), color: Colors.white),
                            SizedBox(width: context.scale(8)),
                            Expanded(
                              child: Text(
                                _questions[_currentIndex].explanation!,
                                style: TextStyle(fontSize: context.scaleFont(13), color: Colors.white),
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

  Widget _buildNothingDue(BuildContext context) {
    final nextReview = _nextReviewAt;
    final String nextReviewText;
    if (nextReview == null) {
      nextReviewText = 'No questions are scheduled yet.';
    } else {
      final diff = nextReview.difference(DateTime.now());
      if (diff.inDays > 0) {
        nextReviewText = diff.inDays == 1
            ? 'Next review is due tomorrow.'
            : 'Next review is due in ${diff.inDays} days.';
      } else if (diff.inHours > 0) {
        nextReviewText = 'Next review is due in ${diff.inHours} hours.';
      } else {
        nextReviewText = 'Next review is due in less than an hour.';
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: context.scale(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_outlined,
              size: context.scale(64),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            SizedBox(height: context.scale(16)),
            Text(
              'All caught up!',
              style: TextStyle(
                fontSize: context.scaleFont(18),
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: context.scale(8)),
            Text(
              nextReviewText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.scaleFont(14),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.scale(24)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startReviewAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: context.scale(14)),
                ),
                child: const Text(
                  'Review all questions anyway',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: context.scale(8)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Lessons'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.scale(16)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
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
              backgroundColor: _showFeedback
                  ? Theme.of(context).colorScheme.primary
                  : (_answers[_currentIndex] != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant),
              padding: EdgeInsets.symmetric(vertical: context.scale(14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _showFeedback ? (_isLastQuestion ? 'Finish' : 'Next') : 'Submit',
                    style: TextStyle(
                      color: _answers[_currentIndex] != null || _showFeedback
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: context.scaleFont(16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
