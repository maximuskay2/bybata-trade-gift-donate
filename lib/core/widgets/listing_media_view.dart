import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../constants/listing_media_constants.dart';
import '../models/listing_media.dart';
import '../utils/listing_video_coordinator.dart';
import '../utils/listing_video_visibility.dart';
import '../utils/media_file_cache.dart';
import '../utils/listing_video_handoff.dart';
import 'cached_media_image.dart';
import 'bybata_loading_indicator.dart';
import 'listing_media_fullscreen.dart';
import 'media_carousel.dart';

/// Displays listing media: image carousel or autoplaying video.
class ListingMediaView extends StatelessWidget {
  final ListingMediaFields media;
  final String heroTag;
  final double? height;
  final double? width;
  final BoxFit fit;
  final bool autoplayVideo;
  final bool showPageIndicator;
  final bool enableZoom;
  final bool expand;
  /// When true and [height] is null, wraps content in feed [AspectRatio] (16:10).
  final bool enforcePortraitAspect;
  final VoidCallback? onMediaTap;
  /// When true, tapping media opens [showListingMediaFullscreen] (detail screens).
  final bool openFullscreenOnTap;
  /// Initial mute state for inline video. Audio is always available via the mute toggle.
  final bool videoMuted;
  final bool showVideoMuteControl;
  /// Browse feed: when [autoplayVideo] is false, poster/thumbnail only.
  /// When [autoplayVideo] is true, inline video with visibility-based autoplay.
  final bool feedMode;
  final String? previewImageUrl;
  final bool showVideoPlayBadge;

  const ListingMediaView({
    super.key,
    required this.media,
    required this.heroTag,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.autoplayVideo = true,
    this.showPageIndicator = true,
    this.enableZoom = false,
    this.expand = false,
    this.enforcePortraitAspect = false,
    this.onMediaTap,
    this.openFullscreenOnTap = false,
    this.videoMuted = false,
    this.showVideoMuteControl = true,
    this.feedMode = false,
    this.previewImageUrl,
    this.showVideoPlayBadge = false,
  });

  factory ListingMediaView.fromJson(
    Map<String, dynamic> json, {
    required String heroTag,
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
    bool autoplayVideo = true,
  }) {
    return ListingMediaView(
      media: ListingMediaFields.fromJson(json),
      heroTag: heroTag,
      height: height,
      width: width,
      fit: fit,
      autoplayVideo: autoplayVideo,
    );
  }

  VoidCallback? _resolveMediaTap(BuildContext context) {
    if (onMediaTap != null) return onMediaTap;
    if (openFullscreenOnTap && media.hasMedia && !media.isVideo) {
      return () => showListingMediaFullscreen(
            context,
            media: media,
            heroTag: heroTag,
          );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final h = height ?? 220.0;
    final w = width ?? double.infinity;
    final mediaTap = _resolveMediaTap(context);

    Widget wrap(Widget child) {
      if (expand) {
        return SizedBox.expand(child: child);
      }
      if (enforcePortraitAspect && height == null) {
        return AspectRatio(
          aspectRatio: ListingMediaConstants.feedAspectRatio,
          child: SizedBox(width: w, child: child),
        );
      }
      return SizedBox(height: h, width: w, child: child);
    }

    if (media.isVideo && feedMode && autoplayVideo) {
      final videoKey = media.videoKey?.trim();
      if (videoKey != null && videoKey.isNotEmpty) {
        return wrap(
          _ListingVideoPlayer(
            videoKey: videoKey,
            posterKey: media.previewImageKey,
            fit: fit,
            autoplay: true,
            initialMuted: videoMuted,
            showMuteControl: showVideoMuteControl,
            onTap: mediaTap,
            heroTag: heroTag,
          ),
        );
      }
    }

    if (media.isVideo && !feedMode) {
      return wrap(
        _ListingVideoPlayer(
          videoKey: media.videoKey!,
          posterKey: media.previewImageKey,
          fit: fit,
          autoplay: autoplayVideo,
          initialMuted: videoMuted,
          showMuteControl: showVideoMuteControl,
          onTap: openFullscreenOnTap ? null : onMediaTap,
          fullscreenMedia: openFullscreenOnTap ? media : null,
          heroTag: heroTag,
        ),
      );
    }

    if (media.mediaKeys.isEmpty) {
      final posterKey = media.previewImageKey;
      if (feedMode &&
          (posterKey != null && posterKey.isNotEmpty ||
              (previewImageUrl != null && previewImageUrl!.trim().isNotEmpty))) {
        return wrap(
          _wrapMediaTap(
            _buildFeedPoster(
              posterKey: posterKey,
              directUrl: previewImageUrl,
              w: w,
              h: h,
            ),
            mediaTap,
          ),
        );
      }
      return wrap(
        _wrapMediaTap(
          ColoredBox(
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.image_not_supported_outlined)),
          ),
          mediaTap,
        ),
      );
    }

    if (feedMode || media.mediaKeys.length == 1) {
      final key = media.previewImageKey ?? media.mediaKeys.first;
      return wrap(
        _wrapMediaTap(
          _buildFeedPoster(
            posterKey: key,
            directUrl: previewImageUrl,
            w: w,
            h: h,
          ),
          mediaTap,
        ),
      );
    }

    return wrap(
      MediaCarousel(
        mediaUrls: media.mediaKeys,
        heroTag: heroTag,
        fit: fit,
        showPageIndicator: showPageIndicator && media.mediaKeys.length > 1,
        enableZoom: enableZoom,
        onImageTap: mediaTap,
      ),
    );
  }

  Widget _wrapMediaTap(Widget child, VoidCallback? tap) {
    if (tap == null) return child;
    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  Widget _buildFeedPoster({
    required String? posterKey,
    String? directUrl,
    required double w,
    required double h,
  }) {
    return Stack(
      fit: expand ? StackFit.expand : StackFit.loose,
      alignment: Alignment.center,
      children: [
        CachedMediaImage(
          mediaKey: posterKey,
          directUrl: directUrl,
          fit: fit,
          width: expand ? null : w,
          height: expand ? null : h,
          optimizedForFeed: true,
        ),
        if (showVideoPlayBadge)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
      ],
    );
  }
}

/// Compact thumb for list cards — autoplay video when applicable.
class ListingMediaThumb extends StatelessWidget {
  final ListingMediaFields media;
  final double size;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const ListingMediaThumb({
    super.key,
    required this.media,
    this.size = 72,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  double get _width => width ?? size;
  double get _height => height ?? size;

  @override
  Widget build(BuildContext context) {
    final posterKey = media.isVideo ? media.previewImageKey : null;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: _width,
        height: _height,
        child: media.isVideo
            ? _buildVideoThumb(posterKey)
            : media.previewImageKey != null
                ? CachedMediaImage(
                    mediaKey: media.previewImageKey!,
                    fit: BoxFit.cover,
                    width: _width,
                    height: _height,
                    optimizedForFeed: true,
                  )
                : media.mediaKeys.isNotEmpty
                    ? CachedMediaImage(
                        mediaKey: media.mediaKeys.first,
                        fit: BoxFit.cover,
                        width: _width,
                        height: _height,
                        optimizedForFeed: true,
                      )
                    : ColoredBox(
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image_outlined, color: Colors.grey.shade500),
                      ),
      ),
    );
  }

  Widget _buildVideoThumb(String? posterKey) {
    if (posterKey != null && posterKey.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedMediaImage(
            mediaKey: posterKey,
            fit: BoxFit.cover,
            width: _width,
            height: _height,
            optimizedForFeed: true,
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      );
    }
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(Icons.videocam_outlined, color: Colors.grey.shade500),
    );
  }
}

class _ListingVideoPlayer extends StatefulWidget {
  final String videoKey;
  final String? posterKey;
  final BoxFit fit;
  final bool autoplay;
  final bool initialMuted;
  final bool showMuteControl;
  final VoidCallback? onTap;
  final ListingMediaFields? fullscreenMedia;
  final String? heroTag;

  const _ListingVideoPlayer({
    required this.videoKey,
    this.posterKey,
    this.fit = BoxFit.cover,
    this.autoplay = true,
    this.initialMuted = false,
    this.showMuteControl = true,
    this.onTap,
    this.fullscreenMedia,
    this.heroTag,
  });

  @override
  State<_ListingVideoPlayer> createState() => _ListingVideoPlayerState();
}

class _ListingVideoPlayerState extends State<_ListingVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _started = false;
  String? _error;
  late bool _isMuted;
  bool _handedOffToFullscreen = false;
  bool _pausedForDetail = false;
  bool _initGeneration = false;
  bool _forcePosterOverlay = false;
  bool _waitingForDecoderSlot = false;
  double _visibleFraction = 0;
  Timer? _androidVisibilityBootstrap;

  bool get _isFeedInline => widget.onTap != null && widget.autoplay;

  bool get _usePosterOnly =>
      !widget.autoplay &&
      widget.posterKey != null &&
      widget.posterKey!.trim().isNotEmpty &&
      !_started;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialMuted;
    if (_isFeedInline) {
      ListingVideoCoordinator.registerAutoplayCallbacks(
        videoKey: widget.videoKey,
        onWon: _syncPlaybackToCoordinator,
        onLost: _syncPlaybackToCoordinator,
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        _androidVisibilityBootstrap = Timer(const Duration(milliseconds: 450), () {
          if (!mounted || _started) return;
          _beginInlinePlayback(ListingVideoVisibility.playThreshold);
        });
      }
      return;
    }
    if (widget.autoplay || widget.posterKey == null) {
      _started = true;
      _scheduleInit();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!_isFeedInline || !mounted) return;
    _androidVisibilityBootstrap?.cancel();
    _visibleFraction = info.visibleFraction;
    ListingVideoCoordinator.reportVisibility(widget.videoKey, _visibleFraction);

    if (_visibleFraction >= ListingVideoVisibility.playThreshold) {
      _forcePosterOverlay = false;
      if (!_started) {
        _beginInlinePlayback(_visibleFraction);
      } else {
        _syncPlaybackToCoordinator();
      }
    } else if (_visibleFraction < ListingVideoVisibility.pauseThreshold) {
      _pauseForLowVisibility();
    }

    if (_visibleFraction < ListingVideoVisibility.releaseThreshold) {
      _releaseDecoderIfFeed();
    }

    if (mounted) setState(() {});
  }

  void _beginInlinePlayback(double visibleFraction) {
    _visibleFraction = visibleFraction;
    ListingVideoCoordinator.reportVisibility(widget.videoKey, visibleFraction);
    _forcePosterOverlay = false;
    if (!_started) {
      _started = true;
      _scheduleInit();
    } else {
      _syncPlaybackToCoordinator();
    }
  }

  void _pauseForLowVisibility() {
    if (!_isFeedInline) {
      _forcePosterOverlay = true;
    }
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _releaseDecoderIfFeed() {
    if (!_isFeedInline || _handedOffToFullscreen || _pausedForDetail) return;
    if (_controller == null && !_started) return;

    ListingVideoHandoff.unregister(widget.videoKey);
    _controller?.dispose();
    _controller = null;
    _started = false;
    _loading = false;
    _initGeneration = false;
    _waitingForDecoderSlot = false;
    ListingVideoCoordinator.releaseDecoder(widget.videoKey);
    ListingVideoCoordinator.releaseAutoplay(widget.videoKey);
  }

  void _syncPlaybackToCoordinator() {
    if (!mounted || _pausedForDetail) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (ListingVideoCoordinator.shouldPlay(widget.videoKey)) {
      _forcePosterOverlay = false;
      if (_isFeedInline) {
        ListingVideoHandoff.pauseAllExcept(widget.videoKey);
      }
      if (!controller.value.isPlaying) {
        unawaited(controller.play().then((_) {
          if (mounted) setState(() {});
        }));
      }
    } else if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _scheduleInit() {
    if (!_started || _initGeneration) return;

    if (_isFeedInline && !ListingVideoCoordinator.tryAcquireDecoder(widget.videoKey)) {
      _waitingForDecoderSlot = true;
      ListingVideoCoordinator.registerDecoderWaiter(
        widget.videoKey,
        () {
          if (!mounted || !_waitingForDecoderSlot) return;
          _waitingForDecoderSlot = false;
          _init();
        },
      );
      return;
    }

    _init();
  }

  @override
  void didUpdateWidget(covariant _ListingVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoKey != widget.videoKey ||
        oldWidget.posterKey != widget.posterKey) {
      ListingVideoCoordinator.unregisterDecoderWaiter(oldWidget.videoKey);
      ListingVideoCoordinator.unregisterAutoplayCallbacks(oldWidget.videoKey);
      ListingVideoCoordinator.releaseDecoder(oldWidget.videoKey);
      ListingVideoCoordinator.releaseAutoplay(oldWidget.videoKey);
      ListingVideoCoordinator.clearVisibility(oldWidget.videoKey);
      _waitingForDecoderSlot = false;
      _forcePosterOverlay = false;
      _disposeController();
      _started = _isFeedInline
          ? false
          : (widget.autoplay || widget.posterKey == null);
      if (_started) _scheduleInit();
    }
  }

  Future<void> _startPlayback() async {
    if (_started) return;
    setState(() {
      _started = true;
      _loading = true;
    });
    await _init();
  }

  Future<void> _init() async {
    if (!_started || _initGeneration) return;
    _initGeneration = true;

    setState(() {
      _loading = true;
      _error = null;
    });

    await ListingVideoCoordinator.acquireInitSlot();
    try {
      final source = await MediaFileCache.resolveForPlayback(widget.videoKey);
      if (!mounted) return;

      if (!source.isValid) {
        if (_isFeedInline) {
          ListingVideoCoordinator.releaseDecoder(widget.videoKey);
        }
        setState(() {
          _loading = false;
          _error = 'Video unavailable';
        });
        return;
      }

      late final VideoPlayerController controller;
      if (source.file != null) {
        controller = VideoPlayerController.file(source.file!);
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(source.streamUrl!));
      }

      await controller.initialize().timeout(const Duration(seconds: 20));
      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0 : 1);

      if (_isFeedInline) {
        ListingVideoCoordinator.tryAcquireDecoder(widget.videoKey);
      }

      final shouldPlay = widget.autoplay &&
          !_pausedForDetail &&
          (!_isFeedInline || ListingVideoCoordinator.shouldPlay(widget.videoKey));
      if (shouldPlay) {
        if (_isFeedInline) {
          ListingVideoHandoff.pauseAllExcept(widget.videoKey);
        }
        await controller.play();
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
      _registerHandoffCallbacks();
    } on TimeoutException {
      if (_isFeedInline) {
        ListingVideoCoordinator.releaseDecoder(widget.videoKey);
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Video timed out';
        });
      }
    } catch (e) {
      if (_isFeedInline) {
        ListingVideoCoordinator.releaseDecoder(widget.videoKey);
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load video';
        });
      }
    } finally {
      ListingVideoCoordinator.releaseInitSlot();
      _initGeneration = false;
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _isMuted = !_isMuted);
    await controller.setVolume(_isMuted ? 0 : 1);
  }

  void _registerHandoffCallbacks() {
    ListingVideoHandoff.register(
      widget.videoKey,
      pause: () {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) return;
        if (controller.value.isPlaying) {
          controller.pause();
          if (mounted) setState(() {});
        }
      },
      pauseForDetail: _pauseForDetailNavigation,
    );
    if (widget.onTap != null) {
      ListingVideoHandoff.registerResume(widget.videoKey, _resumeAfterDetail);
    }
  }

  void _pauseForDetailNavigation() {
    if (_pausedForDetail || _handedOffToFullscreen) return;
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      controller.pause();
    }
    ListingVideoCoordinator.releaseAutoplay(widget.videoKey);
    if (!mounted) return;
    setState(() {
      _pausedForDetail = true;
      _forcePosterOverlay = true;
    });
  }

  Future<void> _resumeAfterDetail() async {
    if (!mounted) return;
    setState(() {
      _pausedForDetail = false;
      _forcePosterOverlay =
          _visibleFraction < ListingVideoVisibility.playThreshold;
    });

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      _syncPlaybackToCoordinator();
      if (mounted) setState(() {});
      return;
    }

    if (widget.autoplay &&
        _visibleFraction >= ListingVideoVisibility.playThreshold) {
      _started = true;
      _scheduleInit();
    }
  }

  Future<void> _handleTap() async {
    if (widget.fullscreenMedia != null && widget.heroTag != null) {
      await _openFullscreenWithHandoff();
      return;
    }
    if (widget.onTap != null) {
      ListingVideoHandoff.prepareDetailNavigation(widget.videoKey);
      widget.onTap!.call();
    }
  }

  Future<void> _openFullscreenWithHandoff() async {
    final media = widget.fullscreenMedia!;
    final heroTag = widget.heroTag!;
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      await showListingMediaFullscreen(
        context,
        media: media,
        heroTag: heroTag,
        initialMuted: _isMuted,
      );
      return;
    }

    final wasPlaying = controller.value.isPlaying;
    await controller.pause();
    setState(() => _handedOffToFullscreen = true);

    final result = await showListingMediaFullscreen(
      context,
      media: media,
      heroTag: heroTag,
      sharedController: controller,
      initialMuted: _isMuted,
    );

    if (!mounted) return;
    setState(() => _handedOffToFullscreen = false);

    if (result != null) {
      _isMuted = result.isMuted;
      await controller.setVolume(_isMuted ? 0 : 1);
      final pos = result.position;
      if (pos != controller.value.position) {
        await controller.seekTo(pos);
      }
      if (result.wasPlaying || wasPlaying) {
        await controller.play();
      }
    } else if (wasPlaying) {
      await controller.play();
    }

    if (mounted) setState(() {});
  }

  void _disposeController() {
    if (_handedOffToFullscreen) return;
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _androidVisibilityBootstrap?.cancel();
    ListingVideoCoordinator.unregisterDecoderWaiter(widget.videoKey);
    ListingVideoCoordinator.unregisterAutoplayCallbacks(widget.videoKey);
    ListingVideoCoordinator.clearVisibility(widget.videoKey);
    ListingVideoCoordinator.releaseDecoder(widget.videoKey);
    ListingVideoCoordinator.releaseAutoplay(widget.videoKey);
    ListingVideoHandoff.unregister(widget.videoKey);
    if (!_handedOffToFullscreen) {
      _controller?.dispose();
      _controller = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildPlayerContent();
    if (!_isFeedInline) return content;
    return VisibilityDetector(
      key: Key('listing_video_${widget.videoKey}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: content,
    );
  }

  Widget _buildPlayerContent() {
    if (_isFeedInline &&
        !_started &&
        !_loading &&
        _controller == null) {
      if (_waitingForDecoderSlot) {
        return _buildFeedInlinePlaceholder();
      }
      return _buildFeedInlinePlaceholder();
    }

    if (_waitingForDecoderSlot && !_loading && _controller == null) {
      if (_isFeedInline) {
        return _buildFeedInlinePlaceholder();
      }
      return _buildPosterOrPlaceholder(showPlayHint: false);
    }

    if (_handedOffToFullscreen) {
      if (widget.posterKey != null && widget.posterKey!.trim().isNotEmpty) {
        return CachedMediaImage(mediaKey: widget.posterKey!, fit: widget.fit);
      }
      return ColoredBox(color: Colors.black, child: const SizedBox.expand());
    }

    if (_usePosterOnly) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedMediaImage(
            mediaKey: widget.posterKey!,
            fit: widget.fit,
          ),
          if (widget.onTap != null || widget.fullscreenMedia != null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.fullscreenMedia != null ? _handleTap : widget.onTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Center(
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _startPlayback,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_loading) {
      if (_isFeedInline) {
        return _buildFeedInlinePlaceholder(loading: true);
      }
      const loader = BybataLoadingIndicator(size: BybataLoadingSize.compact);
      if (widget.posterKey != null && widget.posterKey!.trim().isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedMediaImage(mediaKey: widget.posterKey!, fit: widget.fit),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: BybataLoadingIndicator(
                    size: BybataLoadingSize.compact,
                    color: Colors.white,
                    highlightColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return const Center(child: loader);
    }
    if (_error != null || _controller == null || !_controller!.value.isInitialized) {
      return ColoredBox(
        color: Colors.grey.shade300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, color: Colors.grey.shade600, size: 32),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
        if (_forcePosterOverlay)
          Positioned.fill(
            child: _isFeedInline
                ? const ColoredBox(color: Colors.black)
                : _buildPosterOrPlaceholder(showPlayHint: false),
          ),
        if (widget.onTap != null || widget.fullscreenMedia != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        if (widget.showMuteControl)
          Positioned(
            right: 8,
            bottom: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _toggleMute,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedInlinePlaceholder({bool loading = false}) {
    return ColoredBox(
      color: Colors.black,
      child: loading
          ? const Center(
              child: BybataLoadingIndicator(
                size: BybataLoadingSize.compact,
                color: Colors.white,
                highlightColor: Colors.white70,
              ),
            )
          : const SizedBox.expand(),
    );
  }

  Widget _buildPosterOrPlaceholder({bool showPlayHint = false}) {
    if (widget.posterKey != null && widget.posterKey!.trim().isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedMediaImage(mediaKey: widget.posterKey!, fit: widget.fit),
          if (showPlayHint)
            Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
        ],
      );
    }
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Center(
        child: Icon(
          showPlayHint ? Icons.play_circle_outline : Icons.videocam_outlined,
          color: Colors.grey.shade600,
          size: 32,
        ),
      ),
    );
  }
}
