import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/theme/app_text_styles.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/providers/onboarding.dart';
import 'package:vcroad/presentation/features/onboarding/widgets/slide_report.dart';
import 'package:vcroad/presentation/features/onboarding/widgets/slide_track.dart';
import 'package:vcroad/presentation/features/onboarding/widgets/slide_advisory.dart';
import 'package:vcroad/presentation/features/onboarding/widgets/slide_learn.dart';
import 'package:vcroad/presentation/features/onboarding/widgets/xp_preview.dart';

class OnboardingScreen extends StatefulWidget {
  final UserRole role;
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, required this.role, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _introKey = GlobalKey<IntroductionScreenState>();

  List<PageViewModel> get _pages {
    if (widget.role == UserRole.admin || widget.role == UserRole.sysadmin) {
      return _adminPages();
    }
    return _userPages();
  }

  List<PageViewModel> _userPages() {
    final theme = Theme.of(context);
    final deco = PageDecoration(
      titleTextStyle: AppTextStyles.displayMedium,
      bodyTextStyle: AppTextStyles.bodyLarge,
      bodyPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      pageColor: theme.scaffoldBackgroundColor,
      imagePadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.only(top: 16),
    );
    return [
      PageViewModel(
        title: 'Report Road Issues',
        body: 'Capture and report road hazards, potholes, and other issues in your barangay.',
        image: const SlideReport(),
        decoration: deco,
      ),
      PageViewModel(
        title: 'Track Your Reports',
        body: 'View the status of your submitted reports and follow up on resolutions.',
        image: const SlideTrack(),
        decoration: deco,
      ),
      PageViewModel(
        title: 'Stay Informed',
        body: 'Get real-time traffic advisories and road condition updates for Valenzuela City.',
        image: const SlideAdvisory(),
        decoration: deco,
      ),
      PageViewModel(
        title: 'Road Safety Education',
        body: 'Learn road safety rules and earn XP through interactive lessons.',
        image: const SlideLearn(),
        decoration: deco,
      ),
      PageViewModel(
        title: "You're Ready!",
        body: 'Complete lessons, submit reports, and earn XP to unlock new levels and badges.',
        image: const XpPreview(),
        decoration: deco,
      ),
    ];
  }

  List<PageViewModel> _adminPages() {
    final theme = Theme.of(context);
    final deco = PageDecoration(
      titleTextStyle: AppTextStyles.displayMedium,
      bodyTextStyle: AppTextStyles.bodyLarge,
      bodyPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      pageColor: theme.scaffoldBackgroundColor,
      imagePadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.only(top: 16),
    );
    if (widget.role == UserRole.sysadmin) {
      return [
        PageViewModel(
          title: 'System Overview',
          body: 'Monitor all barangays, manage user accounts, and oversee platform operations.',
          image: const _SysAdminSlide(),
          decoration: deco,
        ),
        PageViewModel(
          title: 'Platform Analytics',
          body: 'Access reports, track resolution rates, and generate insights across the city.',
          image: const SlideLearn(isAdmin: true),
          decoration: deco,
        ),
        PageViewModel(
          title: "You're All Set!",
          body: 'Monitor your jurisdiction, manage reports, and keep Valenzuela City moving safely.',
          image: const _ReadySlide(),
          decoration: deco,
        ),
      ];
    }
    return [
      PageViewModel(
        title: 'Manage Reports',
        body: 'View, assign, and resolve road hazard reports submitted in your barangay.',
        image: const SlideTrack(),
        decoration: deco,
      ),
      PageViewModel(
        title: 'Barangay Dashboard',
        body: 'Oversee your jurisdiction with real-time stats and team coordination tools.',
        image: const SlideLearn(isAdmin: true),
        decoration: deco,
      ),
      PageViewModel(
        title: "You're All Set!",
        body: 'Start managing reports and keeping your barangay roads safe.',
        image: const _ReadySlide(),
        decoration: deco,
      ),
    ];
  }

  Future<void> _onDone() async {
    final provider = context.read<OnboardingProvider>();
    await provider.markTutorialSeen();
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IntroductionScreen(
        key: _introKey,
        globalBackgroundColor: theme.scaffoldBackgroundColor,
        allowImplicitScrolling: true,
        pages: _pages,
        onDone: _onDone,
        onSkip: _onDone,
        showSkipButton: true,
        skipOrBackFlex: 0,
        nextFlex: 0,
        skip: const Text('Skip', style: AppTextStyles.label),
        next: const Icon(Icons.arrow_forward),
        done: const Text("Let's Go!", style: AppTextStyles.label),
        curve: Curves.fastLinearToSlowEaseIn,
        controlsMargin: const EdgeInsets.all(16),
        controlsPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        dotsDecorator: DotsDecorator(
          size: const Size(10, 10),
          color: AppColors.border,
          activeColor: theme.colorScheme.primary,
          activeSize: const Size(22, 10),
          activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
      ),
    );
  }
}

class _SysAdminSlide extends StatelessWidget {
  const _SysAdminSlide();

  @override
  Widget build(BuildContext context) {
    final s = context.scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: s(100), height: s(100),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(s(24)),
          ),
          child: Icon(Icons.admin_panel_settings, size: s(48), color: Theme.of(context).colorScheme.primary),
        ),
        SizedBox(height: s(16)),
        _statRow(context, 'Barangays', '32 Active'),
        SizedBox(height: s(8)),
        _statRow(context, 'Total Reports', '1,284 Resolved'),
        SizedBox(height: s(8)),
        _statRow(context, 'Field Workers', '48 Online'),
      ],
    );
  }

  Widget _statRow(BuildContext context, String label, String value) {
    final s = context.scale;
    return Container(
      width: s(220),
      padding: EdgeInsets.symmetric(horizontal: s(12), vertical: s(8)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(s(8)),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: s(13), fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: s(13), color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReadySlide extends StatelessWidget {
  const _ReadySlide();

  @override
  Widget build(BuildContext context) {
    final s = context.scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: s(80), height: s(80),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(s(20)),
          ),
          child: Icon(Icons.check_circle_rounded, size: s(44), color: Colors.green.shade600),
        ),
        SizedBox(height: s(16)),
        Text('You\'re all set!', style: TextStyle(fontSize: s(22), fontWeight: FontWeight.bold)),
        SizedBox(height: s(8)),
        Text(
          'Start exploring and help make our roads safer.',
          style: TextStyle(fontSize: s(14), color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
