import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/theme/app_text_styles.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class OnboardingScreen extends StatefulWidget {
  final String? userId;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    this.userId,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int? _startStep;

  @override
  void initState() {
    super.initState();
    _determineStartStep();
  }

  Future<void> _determineStartStep() async {
    final prefs = await SharedPreferences.getInstance();
    final tutorialKey = widget.userId == null
        ? 'hasSeenAppTutorial'
        : 'hasSeenAppTutorial_${widget.userId}';
    final tutorialSeen = prefs.getBool(tutorialKey) ?? false;

    final rationaleSeen = prefs.getBool('location_rationale_shown') ?? false;

    int step = 0;
    if (tutorialSeen) step = 1;
    if (rationaleSeen) step = 2;

    if (step >= 2) {
      widget.onComplete();
      return;
    }

    if (mounted) setState(() => _startStep = step);
  }

  Future<void> _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final key = widget.userId == null
        ? 'hasSeenAppTutorial'
        : 'hasSeenAppTutorial_${widget.userId}';
    await prefs.setBool(key, true);
  }

  Future<void> _markRationaleShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_rationale_shown', true);
  }

  void _nextStep() {
    setState(() => _startStep = (_startStep ?? 0) + 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_startStep == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    switch (_startStep) {
      case 0:
        return _buildTutorial();
      case 1:
        return _buildLocationRationale();
      default:
        return _buildReadyScreen();
    }
  }

  Widget _buildImage(String assetName) {
    return Center(
      child: Image.asset(assetName, fit: BoxFit.contain),
    );
  }

  Widget _buildTutorial() {
    final theme = Theme.of(context);

    final pageDecoration = PageDecoration(
      titleTextStyle: AppTextStyles.displayMedium,
      bodyTextStyle: AppTextStyles.bodyLarge,
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: theme.scaffoldBackgroundColor,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: const ValueKey('tutorial'),
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
      onDone: () async {
        await _markTutorialSeen();
        _nextStep();
      },
      onSkip: () async {
        await _markTutorialSeen();
        _nextStep();
      },
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      skip: const Text('Skip', style: AppTextStyles.label),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Done', style: AppTextStyles.label),
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

  Widget _buildLocationRationale() {
    final theme = Theme.of(context);
    final info = context.responsive;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: info.horizontalPadding),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.location_on_rounded,
                size: info.scale(72),
                color: theme.colorScheme.primary,
              ),
              SizedBox(height: info.scale(24)),
              Text(
                'Location Access',
                style: AppTextStyles.displayMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: info.scale(12)),
              Text(
                'To show your position on the map and tag incident reports '
                'with the correct barangay, VCRoad needs access to your '
                "device's location.\n\n"
                'Your location is used only while the app is open and is '
                'never shared outside the app.',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _markRationaleShown();
                    _nextStep();
                  },
                  child: const Text('Continue'),
                ),
              ),
              SizedBox(height: info.scale(16)),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await _markRationaleShown();
                    _nextStep();
                  },
                  child: const Text('Skip'),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadyScreen() {
    final theme = Theme.of(context);
    final info = context.responsive;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: info.horizontalPadding),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.check_circle_rounded,
                size: info.scale(80),
                color: AppColors.success,
              ),
              SizedBox(height: info.scale(24)),
              Text(
                "You're all set!",
                style: AppTextStyles.displayMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: info.scale(12)),
              Text(
                'Start exploring VCRoad and help make our roads safer.',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onComplete,
                  child: const Text("Let's Go"),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
