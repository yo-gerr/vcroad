import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/theme/app_text_styles.dart';

/// Call this to show the tutorial only for first-time users.
/// If [userId] is provided the seen flag is stored per-user:
///   await showTutorialIfFirstTime(context, userId: currentUserId);
Future<void> showTutorialIfFirstTime(
  BuildContext context, {
  String? userId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = userId == null
      ? 'hasSeenAppTutorial'
      : 'hasSeenAppTutorial_$userId';
  final seen = prefs.getBool(key) ?? false;
  if (seen) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const TutorialPage(),
    ),
  );
  await prefs.setBool(key, true);
}

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  void _onDone(BuildContext context) {
    Navigator.of(context).pop();
  }

  Widget _buildImage(String assetName) {
    return Center(
      child: Image.asset(
        assetName,
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pageDecoration = PageDecoration(
      titleTextStyle: AppTextStyles.displayMedium,
      bodyTextStyle: AppTextStyles.bodyLarge,
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: theme.scaffoldBackgroundColor,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      globalBackgroundColor: theme.scaffoldBackgroundColor,
      allowImplicitScrolling: true,
      pages: [
        PageViewModel(
          title: 'Report Road Issues',
          body:
              'Capture and report road hazards, potholes, and other issues in your barangay.',
          image: _buildImage('assets/images/home_page.webp'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'Track Your Reports',
          body:
              'View the status of your submitted reports and follow up on resolutions.',
          image: _buildImage('assets/images/report_page.webp'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'Stay Informed',
          body:
              'Get real-time traffic advisories and road condition updates for Valenzuela City.',
          image: _buildImage('assets/images/advisory.webp'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'Road Safety Education',
          body:
              'Learn road safety rules and best practices through interactive lessons.',
          image: _buildImage('assets/images/learning.webp'),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onDone(context),
      onSkip: () => _onDone(context),
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      skip: Text(
        'Skip',
        style: AppTextStyles.label,
      ),
      next: Icon(Icons.arrow_forward),
      done: Text(
        'Done',
        style: AppTextStyles.label,
      ),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: AppColors.border,
        activeColor: theme.colorScheme.primary,
        activeSize: const Size(22.0, 10.0),
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}
