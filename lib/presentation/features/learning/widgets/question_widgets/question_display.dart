import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/question.dart';
import 'package:vcroad/presentation/providers/learning.dart';
import 'package:vcroad/presentation/features/learning/widgets/question_widgets/multiple_choice_question.dart';
import 'package:vcroad/presentation/features/learning/widgets/question_widgets/true_false_question.dart';
import 'package:vcroad/presentation/features/learning/widgets/question_widgets/identification_question.dart';
import 'package:vcroad/presentation/features/learning/widgets/question_widgets/matching_question.dart';

class QuestionDisplay extends StatelessWidget {
  const QuestionDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LearningProvider>();
    final question = provider.currentQuestion;

    // Precache current and next question images (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheQuestionImages(context, question);
      final nextIndex = provider.currentQuestionIndex + 1;
      if (provider.currentLesson != null &&
          nextIndex < provider.currentLesson!.questions.length) {
        _precacheQuestionImages(
          context,
          provider.currentLesson!.questions[nextIndex],
        );
      }
    });

    if (question == null) {
      return const Center(child: Text('No question available'));
    }

    switch (question.type) {
      case QuestionType.multipleChoice:
        return MultipleChoiceQuestion(question: question);
      case QuestionType.trueFalse:
        return TrueFalseQuestion(question: question);
      case QuestionType.identification:
        return IdentificationQuestion(question: question);
      case QuestionType.matchingType:
        return MatchingQuestion(question: question);
    }
  }

  void _precacheQuestionImages(BuildContext ctx, QuizQuestion? q) {
    if (q == null) return;
    try {
      if (q.questionImage?.remoteUrl != null) {
        precacheImage(NetworkImage(q.questionImage!.remoteUrl!), ctx);
      } else if (q.questionImage?.hasLocal ?? false) {
        final p = q.questionImage!.localPath!;
        if (File(p).existsSync()) precacheImage(FileImage(File(p)), ctx);
      }

      if (q.optionImages != null) {
        for (final img in q.optionImages!) {
          if (img?.remoteUrl != null) {
            precacheImage(NetworkImage(img!.remoteUrl!), ctx);
          } else if (img?.hasLocal ?? false) {
            final p = img!.localPath!;
            if (File(p).existsSync()) precacheImage(FileImage(File(p)), ctx);
          }
        }
      }

      if (q.matchingPairs != null) {
        for (final pair in q.matchingPairs!) {
          if (pair.image.remoteUrl != null) {
            precacheImage(NetworkImage(pair.image.remoteUrl!), ctx);
          } else if (pair.image.hasLocal && pair.image.localPath != null) {
            final p = pair.image.localPath!;
            if (File(p).existsSync()) precacheImage(FileImage(File(p)), ctx);
          }
        }
      }
    } catch (e) {
      // ignore cache failures
      debugPrint('Precache image error: $e');
    }
  }
}
