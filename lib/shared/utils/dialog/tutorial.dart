import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

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
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const TutorialDialog(),
  );
  await prefs.setBool(key, true);
}

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  final PageController _pageController = PageController();
  final List<String> _images = const [
    'assets/images/home_page.webp',
    'assets/images/report_page.webp',
    'assets/images/advisory.webp',
    'assets/images/learning.webp',
  ];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // Precache assets after first frame for snappy transitions.
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheImages());
  }

  void _precacheImages() {
    final info = context.responsive;
    // Target a reasonable logical width for the cached image depending on device.
    final targetLogicalWidth =
        (info.screenWidth * (info.isDesktop ? 0.6 : 0.85)).clamp(320.0, 1200.0);
    final cacheWidth = context.cacheWidthForImage(targetLogicalWidth);
    for (final p in _images) {
      final provider = ResizeImage(AssetImage(p), width: cacheWidth);
      precacheImage(provider, context);
    }
  }

  void _onNext() {
    if (_page < _images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onPrev() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _onSkip() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_images.length, (i) {
        final selected = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 10,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? Colors.blueAccent : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    // Portrait dialog sizing so tutorial images (portrait webp) fit naturally.
    final double maxDialogWidth = info.isDesktop
        ? info.screenWidth * 0.46
        : info.screenWidth * 0.95;
    final double preferredWidth = maxDialogWidth.clamp(
      320.0,
      info.screenWidth * 0.95,
    );
    // Keep a portrait aspect ratio (e.g., 9:16 -> height > width)
    final double preferredHeight = (preferredWidth * 16.0 / 9.0).clamp(
      520.0,
      info.screenHeight * 0.92,
    );

    final dialogWidth = math.min(preferredWidth, info.screenWidth * 0.95);
    final dialogHeight = math.min(preferredHeight, info.screenHeight * 0.92);

    final imageMaxWidth = dialogWidth * 0.94;
    final imageMaxHeight = dialogHeight * 0.78;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: (info.screenWidth - dialogWidth) / 2,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: info.scale(16),
                vertical: info.scale(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick Tour',
                      style: TextStyle(
                        fontSize: info.scaleFont(18),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'Skip',
                      style: TextStyle(fontSize: info.scaleFont(14)),
                    ),
                  ),
                ],
              ),
            ),

            // Page view with portrait images
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _images.length,
                onPageChanged: (idx) => setState(() => _page = idx),
                itemBuilder: (ctx, idx) {
                  final path = _images[idx];
                  final cacheW = context.cacheWidthForImage(imageMaxWidth);
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: info.scale(12),
                      vertical: info.scale(8),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: imageMaxWidth,
                          maxHeight: imageMaxHeight,
                        ),
                        child: Image(
                          image: ResizeImage(AssetImage(path), width: cacheW),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Controls
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: info.scale(16),
                vertical: info.scale(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _page == 0 ? null : _onPrev,
                    icon: Icon(Icons.arrow_back_ios, size: info.scale(18)),
                  ),
                  const Spacer(),
                  _buildDots(),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: info.scale(18),
                        vertical: info.scale(10),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _page < _images.length - 1 ? 'Next' : 'Done',
                      style: TextStyle(fontSize: info.scaleFont(14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
