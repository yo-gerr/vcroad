import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/providers/learning.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/learn/question_widgets/question_display.dart';
import 'package:vcroad_v2/shared/widgets/learn/lesson_result.dart';
import 'package:vcroad_v2/shared/utils/dialog/loading.dart';
import 'package:vcroad_v2/shared/utils/dialog/confirmation.dart';

class LessonViewer extends StatelessWidget {
  const LessonViewer({super.key});

  Future<bool> _onWillPop(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: 'Exit Lesson?',
        message:
            'Your progress will be saved, but you\'ll need to restart this lesson.',
        confirmText: 'Exit',
        cancelText: 'Cancel',
      ),
    );

    if (result == true && context.mounted) {
      context.read<LearningProvider>().exitLesson();
    }

    return false; // Prevent automatic pop
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final provider = context.watch<LearningProvider>();

    if (provider.currentLesson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show results if lesson is complete
    if (provider.isLessonComplete) {
      return const LessonResult();
    }

    final lesson = provider.currentLesson!;
    final progress = provider.currentProgress;
    final questionIndex = provider.currentQuestionIndex;

    // PopScope/onPop signatures vary across SDK versions.
    // Use WillPopScope for compatibility and suppress the deprecation lint until you migrate.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        await _onWillPop(context);
        return false; // prevent automatic pop; _onWillPop handles exit when confirmed
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF001278),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _onWillPop(context),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  lesson.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: info.scaleFont(16),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (provider.hasTimeLimit) ...[
                SizedBox(width: info.scale(8)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: info.scale(8),
                    vertical: info.scale(4),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider.remainingFormatted,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: info.scaleFont(12),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: info.isDesktop ? 900 : double.infinity,
                ),
                child: Column(
                  children: [
                    // Progress Bar
                    Container(
                      height: info.scale(8),
                      color: Colors.grey[200],
                      child: Row(
                        children: [
                          Expanded(
                            flex: questionIndex + 1,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF001278),
                                    Color(0xFF0039E3),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: lesson.questions.length - questionIndex - 1,
                            child: Container(color: Colors.transparent),
                          ),
                        ],
                      ),
                    ),

                    // Question Counter
                    Container(
                      padding: EdgeInsets.all(info.scale(12)),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Question ${questionIndex + 1} of ${lesson.questions.length}',
                            style: TextStyle(
                              fontSize: info.scaleFont(14),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF001278),
                            ),
                          ),
                          if (progress != null) ...[
                            SizedBox(width: info.scale(16)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: info.scale(8),
                                vertical: info.scale(4),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.stars,
                                    size: info.scale(14),
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: info.scale(4)),
                                  Text(
                                    '${progress.pointsEarned}',
                                    style: TextStyle(
                                      fontSize: info.scaleFont(12),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Question Display
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(info.scale(16)),
                        child: const QuestionDisplay(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Saving overlay while provider is completing finalization
            if (provider.isCompleting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: LoadingDialog(message: 'Saving your results...'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
