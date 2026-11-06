import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/navigation/guarded_navigator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/media_file_cache.dart';
import '../../../../core/utils/media_utils.dart';
import '../../../../core/widgets/bybata_loading_indicator.dart';
import '../../services/chat_media_actions.dart';

/// Opens a fullscreen chat media viewer (image or video) with Save / Share.
Future<void> showChatMediaViewer(
  BuildContext context, {
  required String storageKey,
  required ChatMediaKind kind,
  String? fileName,
}) {
  assert(kind == ChatMediaKind.image || kind == ChatMediaKind.video);
  return GuardedNavigator.push<void>(
    context,
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _ChatMediaViewerPage(
        storageKey: storageKey,
        kind: kind,
        fileName: fileName,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
    force: true,
  );
}

class _ChatMediaViewerPage extends StatefulWidget {
  final String storageKey;
  final ChatMediaKind kind;
  final String? fileName;

  const _ChatMediaViewerPage({
    required this.storageKey,
    required this.kind,
    this.fileName,
  });

  @override
  State<_ChatMediaViewerPage> createState() => _ChatMediaViewerPageState();
}

class _ChatMediaViewerPageState extends State<_ChatMediaViewerPage> {
  VideoPlayerController? _videoController;
  bool _loading = true;
  String? _error;
  String? _imageUrl;
  bool _busy = false;
  bool _showVideoChrome = true;

  bool get _isVideo => widget.kind == ChatMediaKind.video;

  Color get _theme => AppTheme.primaryColor;

  @override
  void initState() {
    super.initState();
    // Keep status bar visible so the back control stays reachable.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _load();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (_isVideo) {
        final source =
            await MediaFileCache.resolveForPlayback(widget.storageKey);
        if (!mounted) return;
        if (!source.isValid) {
          setState(() {
            _loading = false;
            _error = 'Video unavailable';
          });
          return;
        }
        final controller = source.file != null
            ? VideoPlayerController.file(source.file!)
            : VideoPlayerController.networkUrl(Uri.parse(source.streamUrl!));
        await controller.initialize();
        await controller.setLooping(true);
        await controller.play();
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() {
          _videoController = controller;
          _loading = false;
        });
      } else {
        final url = await MediaResolver.resolveUrl(widget.storageKey);
        if (!mounted) return;
        if (url == null || !url.startsWith('http')) {
          setState(() {
            _loading = false;
            _error = 'Image unavailable';
          });
          return;
        }
        setState(() {
          _imageUrl = url;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load media';
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    final c = _videoController;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _onSave() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ChatMediaActions.saveToGallery(
        context,
        storageKey: widget.storageKey,
        kind: widget.kind,
        fileName: widget.fileName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onShare() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ChatMediaActions.share(
        context,
        storageKey: widget.storageKey,
        kind: widget.kind,
        fileName: widget.fileName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _themeActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: _theme,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: _theme.withValues(alpha: 0.45),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Media body — tap only toggles video chrome, never the top bar.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isVideo
                  ? () => setState(() => _showVideoChrome = !_showVideoChrome)
                  : null,
              child: Center(child: _buildBody()),
            ),

            // Top bar always visible: Back + Save + Share
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    child: Row(
                      children: [
                        _themeActionButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          onPressed: _close,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isVideo ? 'Video' : 'Photo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_busy)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: _theme,
                              ),
                            ),
                          )
                        else ...[
                          _themeActionButton(
                            icon: Icons.download_rounded,
                            tooltip: 'Save',
                            onPressed: _onSave,
                          ),
                          const SizedBox(width: 10),
                          _themeActionButton(
                            icon: Icons.ios_share_rounded,
                            tooltip: 'Share',
                            onPressed: _onShare,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom minimize / Done — always available
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isVideo &&
                            _showVideoChrome &&
                            _videoController != null &&
                            _videoController!.value.isInitialized)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _themeActionButton(
                              icon: _videoController!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              tooltip: 'Play / Pause',
                              onPressed: _togglePlay,
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _close,
                            style: FilledButton.styleFrom(
                              backgroundColor: _theme,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            label: const Text(
                              'Close',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const BybataLoader();
    }
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          TextButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (_isVideo) {
      final c = _videoController!;
      return AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: VideoPlayer(c),
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Image.network(
        _imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_rounded,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}
