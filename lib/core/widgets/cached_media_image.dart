import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/media_image_loader.dart';
import '../utils/media_utils.dart';

/// Resolves a storage key to a stable URL and displays it with disk + memory cache.
class CachedMediaImage extends StatefulWidget {
  final String? mediaKey;
  final String? directUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final bool optimizedForFeed;

  const CachedMediaImage({
    super.key,
    required this.mediaKey,
    this.directUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.fadeOutDuration = const Duration(milliseconds: 100),
    this.optimizedForFeed = false,
  });

  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  String? _resolvedUrl;
  bool _isResolving = false;
  bool _resolutionFailed = false;
  bool _urlFromCache = false;
  bool get _useDioLoader => !widget.optimizedForFeed;
  Uint8List? _imageBytes;
  bool _loadFailed = false;
  Timer? _loadWatchdog;

  @override
  void initState() {
    super.initState();
    final direct = widget.directUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      _resolvedUrl = direct;
      _urlFromCache = true;
      if (widget.mediaKey != null) {
        MediaResolver.rememberResolvedUrl(widget.mediaKey, direct);
      }
      return;
    }
    final cached = MediaResolver.peekCachedUrl(widget.mediaKey);
    if (cached != null) {
      _resolvedUrl = cached;
      _urlFromCache = true;
      if (_useDioLoader) {
        unawaited(_loadImageBytes(cached));
      }
    } else {
      _resolveUrl();
    }
  }

  @override
  void didUpdateWidget(CachedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaKey != widget.mediaKey ||
        oldWidget.directUrl != widget.directUrl) {
      _loadWatchdog?.cancel();
      _imageBytes = null;
      _loadFailed = false;
      final direct = widget.directUrl?.trim();
      if (direct != null && direct.isNotEmpty) {
        setState(() {
          _resolvedUrl = direct;
          _urlFromCache = true;
          _isResolving = false;
          _resolutionFailed = false;
        });
        if (widget.mediaKey != null) {
          MediaResolver.rememberResolvedUrl(widget.mediaKey, direct);
        }
        return;
      }
      final cached = MediaResolver.peekCachedUrl(widget.mediaKey);
      if (cached != null) {
        setState(() {
          _resolvedUrl = cached;
          _urlFromCache = true;
          _isResolving = false;
          _resolutionFailed = false;
        });
        if (_useDioLoader) {
          unawaited(_loadImageBytes(cached));
        }
      } else {
        _resolveUrl();
      }
    }
  }

  @override
  void dispose() {
    _loadWatchdog?.cancel();
    super.dispose();
  }

  Future<void> _resolveUrl() async {
    if (widget.mediaKey == null || widget.mediaKey!.isEmpty) {
      setState(() => _resolutionFailed = true);
      return;
    }
    if (_isResolving) return;

    setState(() {
      _isResolving = true;
      _resolutionFailed = false;
      _urlFromCache = false;
      _imageBytes = null;
      _loadFailed = false;
    });

    try {
      final url = await MediaResolver.resolveUrl(widget.mediaKey)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _resolvedUrl = url;
        _isResolving = false;
        _resolutionFailed = url == null;
        _urlFromCache =
            url != null && MediaResolver.peekCachedUrl(widget.mediaKey) == url;
      });
      if (url != null && _useDioLoader) {
        unawaited(_loadImageBytes(url));
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _resolutionFailed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _resolutionFailed = true;
        });
      }
    }
  }

  Future<void> _loadImageBytes(String url) async {
    _loadWatchdog?.cancel();
    _loadWatchdog = Timer(const Duration(seconds: 20), () {
      if (!mounted || _imageBytes != null || _loadFailed) return;
      setState(() => _loadFailed = true);
    });

    final storageKey = widget.mediaKey ?? url;
    final bytes = await MediaImageLoader.loadBytes(url, cacheKey: storageKey);
    _loadWatchdog?.cancel();
    if (!mounted) return;

    setState(() {
      if (bytes != null && bytes.isNotEmpty) {
        _imageBytes = bytes;
        _loadFailed = false;
      } else {
        _loadFailed = true;
      }
    });
  }

  Widget _defaultPlaceholder(BuildContext context, {bool loading = false}) {
    final scheme = Theme.of(context).colorScheme;
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: scheme.surfaceContainerHighest,
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : null,
        );
  }

  Widget _defaultError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: scheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: scheme.onSurface.withValues(alpha: 0.35),
          ),
        );
  }

  int? _memCacheDim(double? logical) {
    if (logical == null || !logical.isFinite || logical <= 0) {
      return widget.optimizedForFeed ? 400 : 400;
    }
    final cap = widget.optimizedForFeed ? 800 : 800;
    return (logical * 2).round().clamp(64, cap);
  }

  Widget _buildMemoryImage() {
    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _defaultError(context),
      );
    }
    if (_loadFailed) {
      return _defaultError(context);
    }
    return _defaultPlaceholder(context, loading: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isResolving) {
      return _defaultPlaceholder(context, loading: true);
    }

    if (_resolutionFailed || _resolvedUrl == null) {
      return _defaultError(context);
    }

    if (!MediaResolver.isDecodableImageUrl(_resolvedUrl)) {
      return _defaultError(context);
    }

    if (_useDioLoader) {
      return _buildMemoryImage();
    }

    final memW = _memCacheDim(widget.width);
    final memH = _memCacheDim(widget.height);
    final storageKey = widget.mediaKey ?? _resolvedUrl!;

    return CachedNetworkImage(
      imageUrl: _resolvedUrl!,
      cacheKey: storageKey,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: _urlFromCache ? Duration.zero : widget.fadeInDuration,
      fadeOutDuration: widget.fadeOutDuration,
      useOldImageOnUrlChange: true,
      httpHeaders: const {
        'Accept': 'image/jpeg,image/png,image/webp,image/*;q=0.8',
      },
      placeholder: (context, url) => _defaultPlaceholder(context, loading: true),
      errorWidget: (context, url, error) => _defaultError(context),
      maxHeightDiskCache: widget.optimizedForFeed ? 800 : 1200,
      maxWidthDiskCache: widget.optimizedForFeed ? 800 : 1200,
      memCacheHeight: memH,
      memCacheWidth: memW,
    );
  }
}
