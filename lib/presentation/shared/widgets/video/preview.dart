import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

/// Show a fullscreen video preview dialog (dismissible, close icon top-right).
/// Usage:
///   await showVideoPreviewDialog(context, sourceUrlOrFilePath);
Future<void> showVideoPreviewDialog(BuildContext context, String source) {
  final heroTag = 'video_preview_${identityHashCode(source)}';

  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Video preview',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim1, anim2) {
      return Dismissible(
        key: Key('video_preview_$heroTag'),
        direction: DismissDirection.vertical,
        onDismissed: (_) {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: _VideoDialogContent(source: source, heroTag: heroTag),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _VideoDialogContent extends StatefulWidget {
  final String source;
  final String heroTag;
  const _VideoDialogContent({required this.source, required this.heroTag});

  @override
  State<_VideoDialogContent> createState() => _VideoDialogContentState();
}

class _VideoDialogContentState extends State<_VideoDialogContent> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  VoidCallback? _controllerListener;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _controller = widget.source.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(widget.source))
          : VideoPlayerController.file(File(widget.source));
      await _controller!.initialize();
      // add a listener to update UI whenever controller changes (play/pause/progress)
      _controllerListener = () {
        if (mounted) setState(() {});
      };
      _controller!.addListener(_controllerListener!);
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to load video')));
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  void dispose() {
    if (_controllerListener != null) {
      _controller?.removeListener(_controllerListener!);
    }
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    return Stack(
      children: [
        Center(
          child: _hasError
              ? const Text(
                  'Failed to load video',
                  style: TextStyle(color: Colors.white),
                )
              : (!_initialized || _controller == null)
              ? const CircularProgressIndicator.adaptive()
              : Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller!),
                            _DialogPlayOverlay(
                              controller: _controller!,
                              onToggle: _togglePlay,
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 14,
                              child: VideoProgressIndicator(
                                _controller!,
                                allowScrubbing: true,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                colors: VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(info.scale(12)),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              // toggle playback; UI update comes from controller listener
                              final c = _controller!;
                              c.value.isPlaying ? c.pause() : c.play();
                            },
                            icon: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: info.scale(8)),
                          Expanded(
                            child: Text(
                              widget.source,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        // Close button overlay (top-right) — mirror image preview placement & styling
        Positioned(
          top: info.scale(16),
          right: info.scale(16),
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(
              icon: Icon(
                Icons.close,
                color: Colors.white,
                size: info.scale(28),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Close',
              padding: EdgeInsets.all(info.scale(8)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogPlayOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onToggle;
  const _DialogPlayOverlay({required this.controller, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Fill the available area so taps are always received while respecting
    // later stack children (progress/control widgets) because they are painted after.
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Icon(
                        Icons.play_arrow,
                        size: 56.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
