import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'bybata_loading_indicator.dart';
import 'cached_media_image.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Fullscreen preview for local photos/videos during trade/gift/donation creation.
class LocalListingMediaPreview {
  LocalListingMediaPreview._();

  static Future<void> showPhoto(
    BuildContext context, {
    required File file,
    List<File>? gallery,
    int initialIndex = 0,
  }) async {
    HapticFeedback.selectionClick();
    final files = gallery == null || gallery.isEmpty ? [file] : gallery;
    final index = gallery == null
        ? 0
        : initialIndex.clamp(0, files.length - 1);
    await GuardedNavigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (_, __, ___) => _LocalPhotoPreviewPage(
          files: files,
          initialIndex: index,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static Future<void> showVideo(
    BuildContext context, {
    required String videoPath,
    String? thumbnailPath,
  }) async {
    HapticFeedback.selectionClick();
    await GuardedNavigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (_, __, ___) => _LocalVideoPreviewPage(
          videoPath: videoPath,
          thumbnailPath: thumbnailPath,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static Future<void> showRemotePhoto(
    BuildContext context, {
    required String mediaKey,
  }) async {
    HapticFeedback.selectionClick();
    await GuardedNavigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (_, __, ___) => _RemotePhotoPreviewPage(mediaKey: mediaKey),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _RemotePhotoPreviewPage extends StatelessWidget {
  final String mediaKey;

  const _RemotePhotoPreviewPage({required this.mediaKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedMediaImage(
                  mediaKey: mediaKey,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: _CloseChip(onTap: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalPhotoPreviewPage extends StatefulWidget {
  final List<File> files;
  final int initialIndex;

  const _LocalPhotoPreviewPage({
    required this.files,
    required this.initialIndex,
  });

  @override
  State<_LocalPhotoPreviewPage> createState() => _LocalPhotoPreviewPageState();
}

class _LocalPhotoPreviewPageState extends State<_LocalPhotoPreviewPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.files.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      widget.files[i],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _CloseChip(onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  if (widget.files.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.files.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Text(
                'Pinch to zoom · tap X to close',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalVideoPreviewPage extends StatefulWidget {
  final String videoPath;
  final String? thumbnailPath;

  const _LocalVideoPreviewPage({
    required this.videoPath,
    this.thumbnailPath,
  });

  @override
  State<_LocalVideoPreviewPage> createState() => _LocalVideoPreviewPageState();
}

class _LocalVideoPreviewPageState extends State<_LocalVideoPreviewPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final file = File(widget.videoPath);
      if (!file.existsSync()) {
        setState(() {
          _loading = false;
          _error = 'Video file not found';
        });
        return;
      }
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not play video';
      });
    }
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null) return;
    _muted = !_muted;
    await c.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _loading
                  ? const BybataLoadingIndicator(
                      size: BybataLoadingSize.medium,
                      color: Colors.white,
                    )
                  : _error != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam_off_rounded,
                              color: Colors.white70,
                              size: 42,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: _togglePlay,
                          child: AspectRatio(
                            aspectRatio: c!.value.aspectRatio == 0
                                ? 16 / 10
                                : c.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(c),
                                if (!c.value.isPlaying)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _CloseChip(onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  if (c != null) ...[
                    _RoundAction(
                      icon: _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: c.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onTap: _togglePlay,
                    ),
                  ],
                ],
              ),
            ),
            if (c != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseChip extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
