import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

/// SplashScreen that plays a Lottie animation (once) and shows a subtle
/// scale+fade intro. Waits for precache + min display time + lottie completion
/// (with a safe timeout) before calling onFinish.
class SplashScreen extends StatefulWidget {
  final Duration minDisplay;
  final List<String> assetImagesToPrecache;
  final VoidCallback onFinish;
  final Widget? child; // optional custom fallback widget (used if lottie fails)

  const SplashScreen({
    super.key,
    required this.onFinish,
    this.assetImagesToPrecache = const [],
    this.child,
    Duration? minDisplay,
  }) : minDisplay = minDisplay ?? const Duration(milliseconds: 1400);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // intro animation for fade+scale
  late final AnimationController _introCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  // lottie controller (created when composition is loaded)
  AnimationController? _lottieCtrl;
  final Completer<void> _lottieCompleter = Completer<void>();

  // store composition duration so we can wait appropriately
  Duration? _lottieCompositionDuration;

  @override
  void initState() {
    super.initState();

    final effectiveDuration = kIsWeb
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 1000);

    _introCtrl = AnimationController(vsync: this, duration: effectiveDuration);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeIn));

    // start the intro animation immediately
    _introCtrl.forward();

    _startSequence();
  }

  Future<void> _startSequence() async {
    final precacheFut = _precacheAssets();
    final minDelayFut = Future.delayed(widget.minDisplay);

    // First ensure min display + precache are done (so splash is shown at least minDisplay)
    await Future.wait([precacheFut, minDelayFut]);

    if (!mounted) return;

    // Now wait for the Lottie animation to complete with a dynamic timeout:
    // prefer composition duration + small buffer, otherwise fallback to a safe max.
    final dynamicTimeout = _lottieCompositionDuration != null
        ? _lottieCompositionDuration! + const Duration(milliseconds: 400)
        : const Duration(seconds: 6);

    try {
      await _lottieCompleter.future.timeout(dynamicTimeout);
    } catch (_) {
      // if timeout hits or other error, proceed (we don't want to block forever)
    }

    if (!mounted) return;

    // small finalize animation, then finish
    await _introCtrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 180),
    );

    // brief pause for final frame
    await Future.delayed(const Duration(milliseconds: 120));

    if (mounted) widget.onFinish();
  }

  Future<void> _precacheAssets() async {
    try {
      // preload lottie bytes (best effort, non-blocking)
      const lottiePath = 'assets/lottie/traffic_light.json';
      try {
        await rootBundle.load(lottiePath);
      } catch (_) {
        /* ignore if missing */
      }

      if (!mounted) return;

      // precache only small critical asset images in parallel
      final mq = MediaQuery.maybeOf(context);

      final futures = widget.assetImagesToPrecache.where((p) => p.isNotEmpty).map((
        path,
      ) {
        // compute a reasonable logical size hint to reduce decoded image size in the cache
        final logicalWidth =
            (mq?.size.shortestSide ?? 200) * 0.25; // conservative default
        // pass Size hint to precacheImage so engines can choose an appropriate cache size
        return precacheImage(
          AssetImage(path),
          context,
          size: Size(logicalWidth, logicalWidth),
          onError: (_, __) {},
        );
      }).toList();

      if (futures.isNotEmpty) await Future.wait(futures);
      if (!mounted) return;
    } catch (_) {
      // ignore; don't block startup on precache failure
    }
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _lottieCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prefer using your responsive helpers so splash adapts to mobile/tablet/desktop.
    final info = context.responsive;
    // Use recommended logo size but clamp to safe min/max
    final logoSize = info.logoSize.clamp(64.0, 420.0);

    // Keep layout simple and centered across screen sizes.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _introCtrl,
            builder: (context, child) {
              final o = _opacity.value;
              final s = _scale.value;
              return Opacity(
                opacity: o,
                child: Transform.scale(scale: s, child: child),
              );
            },
            child: Semantics(
              label: 'App splash animation',
              container: true,
              child: RepaintBoundary(
                child: SizedBox(
                  // On wide screens use a fractional width to avoid overly large Lottie playback
                  width: info.isDesktop ? logoSize : logoSize,
                  height: logoSize,
                  child: _buildLottie(context, logoSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLottie(BuildContext context, double size) {
    const assetPath = 'assets/lottie/traffic_light.json';

    final lottie = LottieBuilder.asset(
      assetPath,
      animate: false, // disable internal auto-play; we drive via controller
      repeat: false, // explicitly do not loop
      controller: _lottieCtrl,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        if (_lottieCompleter.isCompleted) return;

        // store composition duration for waiting logic above
        _lottieCompositionDuration = composition.duration;

        _lottieCtrl?.dispose();
        _lottieCtrl =
            AnimationController(vsync: this, duration: composition.duration)
              ..addStatusListener((status) {
                if (status == AnimationStatus.completed &&
                    !_lottieCompleter.isCompleted) {
                  _lottieCompleter.complete();
                }
              });

        // start play once
        _lottieCtrl!.forward();

        // rebuild so the controller is passed to the Lottie widget (only when controller is created)
        if (mounted) setState(() {});
      },
      errorBuilder: (context, error, stackTrace) =>
          widget.child ?? _fallbackBox(context, size),
    );

    return lottie;
  }

  Widget _fallbackBox(BuildContext context, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Text(
        'VCRoad',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: size * 0.24,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
