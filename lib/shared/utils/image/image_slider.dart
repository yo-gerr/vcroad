import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ImageSlider extends StatefulWidget {
  final List<String> images;
  final bool assets;
  final double? height;
  final BoxFit fit;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration autoPlayAnimationDuration;
  final bool enableInfiniteScroll;
  final bool showIndicators;
  final Curve animationCurve;
  final int initialPage;

  const ImageSlider({
    super.key,
    required this.images,
    this.assets = true,
    this.height,
    this.fit = BoxFit.contain,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.autoPlayAnimationDuration = const Duration(milliseconds: 600),
    this.enableInfiniteScroll = true,
    this.showIndicators = true,
    this.animationCurve = Curves.easeInOut,
    this.initialPage = 0,
  });

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  late final CarouselSliderController _controller;
  int _active = 0;

  // Aspect ratios for images (width / height). Null until resolved.
  late final List<double?> _aspectRatios;
  // Keep streams & listeners to remove on dispose
  late final List<ImageStream?> _streams;
  late final List<ImageStreamListener?> _listeners;

  @override
  void initState() {
    super.initState();
    _controller = CarouselSliderController();
    _aspectRatios = List<double?>.filled(widget.images.length, null);
    _streams = List<ImageStream?>.filled(widget.images.length, null);
    _listeners = List<ImageStreamListener?>.filled(widget.images.length, null);

    // Resolve image sizes for assets/network to maintain original aspect ratio.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var i = 0; i < widget.images.length; i++) {
        _resolveImage(i);
      }
      if (widget.assets) {
        _precacheAssets();
      }
    });
  }

  Future<void> _precacheAssets() async {
    for (final path in widget.images) {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {
        // ignore precache errors; item will still render and show fallback if missing
      }
    }
  }

  void _resolveImage(int index) {
    if (!mounted) return;
    final path = widget.images[index];
    final ImageProvider provider = widget.assets
        ? AssetImage(path)
        : NetworkImage(path);
    final ImageConfiguration config = createLocalImageConfiguration(context);
    final ImageStream stream = provider.resolve(config);
    _streams[index] = stream;

    final listener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        final image = info.image;
        if (image.height == 0) return;
        final ratio = image.width / image.height;
        if (!mounted) return;
        if (_aspectRatios[index] != ratio) {
          setState(() {
            _aspectRatios[index] = ratio;
          });
        }
      },
      onError: (_, __) {
        // ignore individual resolution errors
      },
    );

    stream.addListener(listener);
    _listeners[index] = listener;
  }

  @override
  void dispose() {
    for (var i = 0; i < _streams.length; i++) {
      final s = _streams[i];
      final l = _listeners[i];
      if (s != null && l != null) {
        try {
          s.removeListener(l);
        } catch (_) {}
      }
    }
    super.dispose();
  }

  double _primaryAspect() {
    for (final r in _aspectRatios) {
      if (r != null && r > 0) return r;
    }
    // fallback aspect ratio (landscape)
    return 16 / 9;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return SizedBox(
        height: widget.height ?? 200,
        child: const Center(child: SizedBox()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.of(context);
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mq.size.width;
        final maxHConstraint = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;
        final screenH = mq.size.height;

        // Prefer a resolved aspect (first available), otherwise fallback
        final imageAspect = _primaryAspect();

        // Compute the max allowed height for slider:
        // - If parent provided a bounded height, use that as cap.
        // - Otherwise cap to a fraction of viewport to avoid forcing scroll.
        final double viewportCap = screenH * 0.85;
        final double maxAllowedHeight = widget.height != null
            ? widget.height!.clamp(120.0, viewportCap)
            : math.min(
                maxHConstraint.isFinite ? maxHConstraint : viewportCap,
                viewportCap,
              );

        // Natural height when using full available width
        final double naturalHeight = maxW / imageAspect;

        double finalWidth;
        double finalHeight;

        // If natural height fits the allowed height, use full width.
        if (naturalHeight <= maxAllowedHeight) {
          finalWidth = maxW;
          finalHeight = naturalHeight;
        } else {
          // Otherwise limit height to maxAllowedHeight and shrink width to keep aspect
          finalHeight = maxAllowedHeight.clamp(120.0, viewportCap);
          finalWidth = finalHeight * imageAspect;
          // ensure width not exceed maxW
          if (finalWidth > maxW) {
            finalWidth = maxW;
            finalHeight = finalWidth / imageAspect;
          }
        }

        // Ensure final values are reasonable
        finalWidth = finalWidth.isFinite ? finalWidth : maxW;
        finalHeight = finalHeight.isFinite
            ? finalHeight
            : math.min(naturalHeight, viewportCap);

        final devicePixelRatio = mq.devicePixelRatio;
        final cacheWidth = (finalWidth * devicePixelRatio).round();

        return Center(
          child: SizedBox(
            width: finalWidth,
            height: finalHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CarouselSlider.builder(
                  carouselController: _controller,
                  itemCount: widget.images.length,
                  itemBuilder: (context, index, realIndex) {
                    final path = widget.images[index];

                    Widget img;
                    if (widget.assets) {
                      img = Image.asset(
                        path,
                        fit: widget.fit,
                        width: finalWidth,
                        height: finalHeight,
                        cacheWidth: cacheWidth,
                        gaplessPlayback: true,
                        errorBuilder: (c, e, s) =>
                            const Center(child: Icon(Icons.broken_image)),
                      );
                    } else {
                      img = Image.network(
                        path,
                        fit: widget.fit,
                        width: finalWidth,
                        height: finalHeight,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) =>
                            const Center(child: Icon(Icons.broken_image)),
                        gaplessPlayback: true,
                      );
                    }

                    // Since the container already matches the image aspect (or is constrained),
                    // render the image sized to container to preserve original ratio visually.
                    return Center(
                      child: SizedBox(
                        width: finalWidth,
                        height: finalHeight,
                        child: img,
                      ),
                    );
                  },
                  options: CarouselOptions(
                    height: finalHeight,
                    viewportFraction: 1.0,
                    autoPlay: widget.autoPlay,
                    autoPlayInterval: widget.autoPlayInterval,
                    autoPlayAnimationDuration: widget.autoPlayAnimationDuration,
                    pauseAutoPlayOnTouch: true,
                    pauseAutoPlayInFiniteScroll: true, // if supported by lib
                    enableInfiniteScroll: widget.enableInfiniteScroll,
                    enlargeCenterPage: false,
                    initialPage: widget.initialPage,
                    onPageChanged: (index, reason) =>
                        setState(() => _active = index),
                    scrollPhysics: const BouncingScrollPhysics(),
                    disableCenter: true,
                    scrollDirection: Axis.horizontal,
                    pageSnapping: true,
                    autoPlayCurve: widget.animationCurve,
                  ),
                ),

                if (widget.showIndicators)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: math.max(6.0, finalHeight * 0.03),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.images.length, (i) {
                        final active = i == _active;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 10 : 6,
                          height: active ? 10 : 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white70,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
