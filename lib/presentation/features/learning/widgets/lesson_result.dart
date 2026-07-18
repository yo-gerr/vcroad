import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/presentation/providers/learning.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:confetti/confetti.dart';

class LessonResult extends StatefulWidget {
  const LessonResult({super.key});

  @override
  State<LessonResult> createState() => _LessonResultState();
}

class _LessonResultState extends State<LessonResult> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    final provider = context.read<LearningProvider>();
    if (provider.currentProgress?.isPassed ?? false) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleExit() {
    context.read<LearningProvider>().exitLesson();
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final provider = context.watch<LearningProvider>();
    final progress = provider.currentProgress;
    final lesson = provider.currentLesson;

    if (progress == null || lesson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPassed = progress.isPassed;
    final percentage = progress.scorePercentage;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: info.isDesktop ? 700 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(info.scale(20)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Result Icon
                    Container(
                      padding: EdgeInsets.all(info.scale(24)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isPassed ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        isPassed ? Icons.emoji_events : Icons.pending_actions,
                        size: info.scale(80),
                        color: isPassed ? Colors.amber : Colors.orange,
                      ),
                    ),
                    SizedBox(height: info.scale(24)),

                    // Title
                    Text(
                      isPassed ? 'Congratulations!' : 'Keep Practicing!',
                      style: TextStyle(
                        fontSize: info.scaleFont(28),
                        fontWeight: FontWeight.bold,
                        color: isPassed ? Colors.green : Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: info.scale(8)),
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: info.scaleFont(16),
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: info.scale(32)),

                    // Score Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(info.scale(24)),
                        child: Column(
                          children: [
                            // Score Circle
                            SizedBox(
                              width: info.scale(150),
                              height: info.scale(150),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: info.scale(150),
                                    height: info.scale(150),
                                    child: CircularProgressIndicator(
                                      value: percentage / 100,
                                      strokeWidth: info.scale(12),
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation(
                                        isPassed ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: info.scaleFont(36),
                                          fontWeight: FontWeight.bold,
                                          color: isPassed
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                      Text(
                                        isPassed ? 'Passed' : 'Not Passed',
                                        style: TextStyle(
                                          fontSize: info.scaleFont(14),
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: info.scale(24)),

                            // Stats
                            Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    icon: Icons.check_circle,
                                    label: 'Correct',
                                    value:
                                        '${progress.questionsCorrect}/${progress.totalQuestions}',
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(width: info.scale(12)),
                                Expanded(
                                  child: _StatItem(
                                    icon: Icons.stars,
                                    label: 'Points',
                                    value:
                                        '${progress.pointsEarned}/${progress.totalPoints}',
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: info.scale(24)),

                    // Message
                    Container(
                      padding: EdgeInsets.all(info.scale(16)),
                      decoration: BoxDecoration(
                        color: (isPassed ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPassed
                            ? 'Great job! You\'ve successfully completed this lesson. Keep up the good work!'
                            : 'You need at least 70% to pass. Review the material and try again!',
                        style: TextStyle(
                          fontSize: info.scaleFont(14),
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: info.scale(32)),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleExit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF001278),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: info.scale(16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Back to Lessons',
                          style: TextStyle(
                            fontSize: info.scaleFont(16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (!isPassed) ...[
                      SizedBox(height: info.scale(12)),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            // Restart lesson
                            context.read<LearningProvider>().startLesson(
                              lesson.id,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: info.scale(16),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: info.scaleFont(16),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Confetti
          if (isPassed)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.2,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Container(
      padding: EdgeInsets.all(info.scale(16)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: info.scale(28)),
          SizedBox(height: info.scale(8)),
          Text(
            value,
            style: TextStyle(
              fontSize: info.scaleFont(18),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: info.scaleFont(12),
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
