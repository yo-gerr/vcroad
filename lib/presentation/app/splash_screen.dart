import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class SplashScreen extends StatefulWidget {
  final Duration minDisplay;
  final List<String> assetImagesToPrecache;
  final VoidCallback onFinish;
  final Widget? child;

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
  late final AnimationController _introCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  AnimationController? _lottieCtrl;
  final Completer<void> _lottieCompleter = Completer<void>();
  Duration? _lottieCompositionDuration;

  bool _precacheDone = false;
  bool _lottieLoaded = false;
  bool _lottieFailed = false;

  bool get _useAnimations =>
      !PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;

  @override
  void initState() {
    super.initState();

    if (_useAnimations) {
      final effectiveDuration = kIsWeb
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 1000);

      _introCtrl = AnimationController(
        vsync: this,
        duration: effectiveDuration,
      );
      _scale = Tween<double>(
        begin: 0.9,
        end: 1.0,
      ).animate(
        CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic),
      );
      _opacity = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeIn));

      _introCtrl.forward();
    } else {
      _introCtrl = AnimationController(vsync: this, duration: Duration.zero);
      _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_introCtrl);
      _opacity = Tween<double>(begin: 1.0, end: 1.0).animate(_introCtrl);
    }

    _startSequence();
  }

  Future<void> _startSequence() async {
    final precacheFut = _precacheAssets().then((_) => _precacheDone = true);
    final minDelayFut = Future.delayed(widget.minDisplay);

    await Future.wait([precacheFut, minDelayFut]);
    if (!mounted) return;

    if (_lottieCompositionDuration != null && _useAnimations) {
      final dynamicTimeout = _lottieCompositionDuration! +
          const Duration(milliseconds: 400);
      try {
        await _lottieCompleter.future.timeout(dynamicTimeout);
      } catch (_) {}
    } else {
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted) return;

    if (_useAnimations) {
      await _introCtrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 180),
      );
      await Future.delayed(const Duration(milliseconds: 120));
    }

    if (mounted) widget.onFinish();
  }

  Future<void> _precacheAssets() async {
    try {
      const lottiePath = 'assets/lottie/traffic_light.json';
      try {
        await rootBundle.load(lottiePath);
      } catch (_) {}

      if (!mounted) return;

      final mq = MediaQuery.maybeOf(context);
      final futures = widget.assetImagesToPrecache
          .where((p) => p.isNotEmpty)
          .map((path) {
        final logicalWidth = (mq?.size.shortestSide ?? 200) * 0.25;
        return precacheImage(
          AssetImage(path),
          context,
          size: Size(logicalWidth, logicalWidth),
          onError: (_, _) {},
        );
      }).toList();

      if (futures.isNotEmpty) await Future.wait(futures);
      if (!mounted) return;
    } catch (_) {}
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _lottieCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final logoSize = info.logoSize.clamp(64.0, 420.0);
    final animSize = info.isDesktop ? logoSize * 0.8 : logoSize;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _useAnimations
                  ? AnimatedBuilder(
                      animation: _introCtrl,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _opacity.value,
                          child: Transform.scale(
                            scale: _scale.value,
                            child: child,
                          ),
                        );
                      },
                      child: _buildContent(animSize, logoSize),
                    )
                  : _buildContent(animSize, logoSize),
            ),
          ),
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildContent(double animSize, double logoSize) {
    return Semantics(
      label: 'App splash animation',
      container: true,
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: animSize,
              height: animSize,
              child: _buildLottie(animSize),
            ),
            SizedBox(height: math.max(logoSize * 0.06, 12)),
            Text(
              'VCRoad',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: math.max(logoSize * 0.14, 24),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: math.max(logoSize * 0.025, 4)),
            Text(
              'Road Safety &\nIncident Reporting',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: math.max(logoSize * 0.06, 13),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final isLoading = !_precacheDone || !_lottieLoaded;
    if (!isLoading && _lottieCompleter.isCompleted) {
      return const SizedBox(height: 4);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 48, left: 48, right: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lottieFailed ? 'Starting…' : 'Loading…',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLottie(double size) {
    const assetPath = 'assets/lottie/traffic_light.json';

    if (_lottieFailed) {
      return _fallbackBox(size);
    }

    final lottie = LottieBuilder.asset(
      assetPath,
      animate: false,
      repeat: false,
      controller: _useAnimations ? _lottieCtrl : null,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        if (_lottieCompleter.isCompleted) return;
        _lottieLoaded = true;
        _lottieCompositionDuration = composition.duration;

        _lottieCtrl?.dispose();

        if (_useAnimations) {
          _lottieCtrl = AnimationController(
            vsync: this,
            duration: composition.duration,
          )..addStatusListener((status) {
              if (status == AnimationStatus.completed &&
                  !_lottieCompleter.isCompleted) {
                _lottieCompleter.complete();
              }
            });

          _lottieCtrl!.forward();
        } else {
          _lottieCompleter.complete();
        }

        if (mounted) setState(() {});
      },
      errorBuilder: (context, error, stackTrace) {
        _lottieFailed = true;
        if (!_lottieCompleter.isCompleted) {
          _lottieCompleter.complete();
        }
        return widget.child ?? _fallbackBox(size);
      },
    );

    return lottie;
  }

  Widget _fallbackBox(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(
          Icons.traffic_rounded,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
