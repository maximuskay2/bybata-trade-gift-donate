import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/media_utils.dart';
import 'cached_media_image.dart';
import 'package:bybata/core/widgets/bybata_loading_indicator.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> mediaUrls;
  final String heroTag;
  final bool showPageIndicator;
  final bool enableZoom;
  final bool autoResolveMediaKeys;
  final Function(int)? onPageChanged;
  final Duration? autoPlayDuration;
  final BoxFit fit;
  final VoidCallback? onImageTap;

  const MediaCarousel({
    super.key,
    required this.mediaUrls,
    required this.heroTag,
    this.showPageIndicator = true,
    this.enableZoom = false,
    this.autoResolveMediaKeys = true,
    this.onPageChanged,
    this.autoPlayDuration,
    this.fit = BoxFit.cover,
    this.onImageTap,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.autoResolveMediaKeys) {
      _warmUrlCache();
    }
  }

  @override
  void didUpdateWidget(covariant MediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrls != widget.mediaUrls && widget.autoResolveMediaKeys) {
      _warmUrlCache();
    }
  }

  /// Warm URL cache in the background — never block the carousel UI.
  void _warmUrlCache() {
    unawaited(MediaResolver.resolveUrls(widget.mediaUrls));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;
    final imagesToShow =
        widget.mediaUrls.isNotEmpty ? widget.mediaUrls : const <String>[];

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
            widget.onPageChanged?.call(index);
          },
          itemCount: imagesToShow.isNotEmpty ? imagesToShow.length : 1,
          itemBuilder: (context, index) {
            if (imagesToShow.isEmpty) {
              return _placeholderImage();
            }
            return GestureDetector(
              onTap: widget.onImageTap,
              behavior: HitTestBehavior.opaque,
              child: Hero(
                tag: '${widget.heroTag}_$index',
                child: CachedMediaImage(
                  mediaKey: imagesToShow[index],
                  fit: widget.fit,
                  fadeInDuration: MediaResolver.peekCachedUrl(imagesToShow[index]) != null
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  placeholder: _placeholderImage(loading: true),
                  errorWidget: _placeholderImage(),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ),
        if (widget.showPageIndicator && imagesToShow.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imagesToShow.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? primaryColor
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholderImage({bool loading = false}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: loading
            ? const BybataLoadingIndicator(size: BybataLoadingSize.compact)
            : Icon(
                Icons.image_not_supported,
                size: 64,
                color: Colors.grey[400],
              ),
      ),
    );
  }
}
