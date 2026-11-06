import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/listing_media.dart';
import '../utils/media_utils.dart';
import '../utils/media_file_cache.dart';
import 'cached_media_image.dart';
import 'bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Playback state returned when closing fullscreen after sharing a controller.
class ListingVideoFullscreenResult {
  final Duration position;
  final bool isMuted;
  final bool wasPlaying;

  const ListingVideoFullscreenResult({
    required this.position,
    required this.isMuted,
    required this.wasPlaying,
  });
}

/// Opens listing media in an immersive fullscreen viewer (images swipe, video plays with audio).
///
/// When [sharedController] is provided the inline player is paused and the same
/// controller continues at the current position — no duplicate playback.
Future<ListingVideoFullscreenResult?> showListingMediaFullscreen(
  BuildContext context, {
  required ListingMediaFields media,
  required String heroTag,
  int initialIndex = 0,
  VideoPlayerController? sharedController,
  bool initialMuted = false,
}) {
  return GuardedNavigator.push<ListingVideoFullscreenResult>(
    context,
    PageRouteBuilder<ListingVideoFullscreenResult>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _ListingMediaFullscreenPage(
        media: media,
        heroTag: heroTag,
        initialIndex: initialIndex,
        sharedController: sharedController,
        initialMuted: initialMuted,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ListingMediaFullscreenPage extends StatefulWidget {
  final ListingMediaFields media;
  final String heroTag;
  final int initialIndex;
  final VideoPlayerController? sharedController;
  final bool initialMuted;

  const _ListingMediaFullscreenPage({
    required this.media,
    required this.heroTag,
    required this.initialIndex,
    this.sharedController,
    this.initialMuted = false,
  });

  @override
  State<_ListingMediaFullscreenPage> createState() =>
      _ListingMediaFullscreenPageState();
}

class _ListingMediaFullscreenPageState extends State<_ListingMediaFullscreenPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  bool _ownsController = true;
  bool _videoLoading = true;
  String? _videoError;
  late bool _isMuted;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 999);
    _pageController = PageController(initialPage: _currentIndex);
    _isMuted = widget.initialMuted;

    if (widget.media.isVideo) {
      final shared = widget.sharedController;
      if (shared != null && shared.value.isInitialized) {
        _videoController = shared;
        _ownsController = false;
        _videoLoading = false;
        _applyAudioAndResume();
      } else {
        _initVideo();
      }
    } else {
      _videoLoading = false;
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _applyAudioAndResume() async {
    final controller = _videoController;
    if (controller == null) return;
    await controller.setVolume(_isMuted ? 0 : 1);
    if (!controller.value.isPlaying) {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    if (_ownsController) {
      _videoController?.dispose();
    } else {
      // Leave controller alive for inline player; pause so it doesn't bleed audio.
      _videoController?.pause();
    }
    super.dispose();
  }

  ListingVideoFullscreenResult _buildResult() {
    final controller = _videoController;
    return ListingVideoFullscreenResult(
      position: controller?.value.position ?? Duration.zero,
      isMuted: _isMuted,
      wasPlaying: controller?.value.isPlaying ?? false,
    );
  }

  void _close() {
    Navigator.pop(context, _buildResult());
  }

  Future<void> _initVideo() async {
    final key = widget.media.videoKey;
    if (key == null || key.trim().isEmpty) {
      setState(() {
        _videoLoading = false;
        _videoError = 'Video unavailable';
      });
      return;
    }
    try {
      final source = await MediaFileCache.resolveForPlayback(key);
      if (!mounted) return;

      if (!source.isValid) {
        setState(() {
          _videoLoading = false;
          _videoError = 'Video unavailable';
        });
        return;
      }

      late final VideoPlayerController controller;
      if (source.file != null) {
        controller = VideoPlayerController.file(source.file!);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(source.streamUrl!));
      }

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0 : 1);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _ownsController = true;
        _videoLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoLoading = false;
          _videoError = 'Could not load video';
        });
      }
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _restartFromBeginning() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
    if (mounted) setState(() => _showControls = true);
  }

  Future<void> _toggleMute() async {
    final controller = _videoController;
    if (controller == null) return;
    setState(() => _isMuted = !_isMuted);
    await controller.setVolume(_isMuted ? 0 : 1);
  }

  Future<void> _seekTo(double fraction) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    );
    await controller.seekTo(target);
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.media.isVideo)
            _buildVideoBody()
          else
            _buildImageBody(),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _close,
              ),
            ),
          ),
          if (!widget.media.isVideo && widget.media.mediaKeys.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    '${_currentIndex + 1}/${widget.media.mediaKeys.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageBody() {
    final keys = widget.media.mediaKeys;
    if (keys.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 64),
      );
    }

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (i) => setState(() => _currentIndex = i),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: Hero(
              tag: '${widget.heroTag}_$index',
              child: CachedMediaImage(
                mediaKey: keys[index],
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoBody() {
    if (_videoLoading) {
      return const Center(
        child: BybataLoadingIndicator(
          size: BybataLoadingSize.medium,
          color: Colors.white,
          highlightColor: Colors.white,
        ),
      );
    }
    if (_videoError != null || _videoController == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
            if (_videoError != null) ...[
              const SizedBox(height: 8),
              Text(_videoError!, style: const TextStyle(color: Colors.white70)),
            ],
          ],
        ),
      );
    }

    final controller = _videoController!;

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying && _showControls)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
            ),
          if (_showControls)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: _VideoControls(
                  controller: controller,
                  isMuted: _isMuted,
                  formatDuration: _formatDuration,
                  onTogglePlay: _toggleVideoPlayback,
                  onToggleMute: _toggleMute,
                  onRestart: _restartFromBeginning,
                  onSeek: _seekTo,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  final bool isMuted;
  final String Function(Duration) formatDuration;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onRestart;
  final ValueChanged<double> onSeek;

  const _VideoControls({
    required this.controller,
    required this.isMuted,
    required this.formatDuration,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onRestart,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final position = value.position;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: duration.inMilliseconds > 0 ? onSeek : null,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: onTogglePlay,
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: onRestart,
                      tooltip: 'Restart from beginning',
                      icon: const Icon(Icons.replay_rounded, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: onToggleMute,
                      icon: Icon(
                        isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${formatDuration(position)} / ${formatDuration(duration)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
