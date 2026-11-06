import 'package:flutter/material.dart';

import '../../../../core/widgets/cached_media_image.dart';
import '../../services/chat_media_actions.dart';
import 'chat_media_viewer.dart';

/// Inline chat image — Facebook/WhatsApp style:
/// fixed-size placeholder, disk-cached image, no FutureBuilder restart flicker.
class ChatImageAttachment extends StatelessWidget {
  final String storageKey;
  final double width;
  final String? fileName;

  const ChatImageAttachment({
    super.key,
    required this.storageKey,
    this.width = 240,
    this.fileName,
  });

  static const double _height = 180;

  void _open(BuildContext context) {
    showChatMediaViewer(
      context,
      storageKey: storageKey,
      kind: ChatMediaKind.image,
      fileName: fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor =
        isDark ? const Color(0xFF2A2A32) : const Color(0xFFE8E8ED);

    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedMediaImage(
              mediaKey: storageKey,
              width: width,
              height: _height,
              fit: BoxFit.cover,
              // Instant swap when cached — no fade cascade across bubbles.
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              optimizedForFeed: true,
              placeholder: ColoredBox(color: placeholderColor),
              errorWidget: ColoredBox(
                color: placeholderColor,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.white54),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline chat video — static poster card (no VideoPlayer in the list).
/// Messaging apps avoid initializing N players while scrolling; tap opens
/// the fullscreen player instead.
class ChatVideoAttachment extends StatelessWidget {
  final String storageKey;
  final double width;
  final String? fileName;

  const ChatVideoAttachment({
    super.key,
    required this.storageKey,
    this.width = 240,
    this.fileName,
  });

  static const double _height = 180;

  void _openFullscreen(BuildContext context) {
    showChatMediaViewer(
      context,
      storageKey: storageKey,
      kind: ChatMediaKind.video,
      fileName: fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A22) : const Color(0xFF2C2C34);

    return GestureDetector(
      onTap: () => _openFullscreen(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: bg),
            // Soft gradient so the card doesn't look flat/empty while offline.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(14),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
