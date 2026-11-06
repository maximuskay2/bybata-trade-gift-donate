import 'dart:ui';

import 'package:flutter/material.dart';

/// Kind of media being uploaded — drives icon, accent, and copy.
enum ChatUploadKind { photo, video, document }

/// Compact glass upload overlay used while chat media is uploading/sending.
///
/// Replaces the stock [AlertDialog] so the progress UI matches the chat
/// composer (frosted card, soft scrim, typed icon).
class ChatUploadOverlay extends StatelessWidget {
  final ChatUploadKind kind;
  final String? fileName;

  const ChatUploadOverlay({
    super.key,
    required this.kind,
    this.fileName,
  });

  static Future<void> show(
    BuildContext context, {
    required ChatUploadKind kind,
    String? fileName,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Uploading',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondary) {
        return PopScope(
          canPop: false,
          child: ChatUploadOverlay(kind: kind, fileName: fileName),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  IconData get _icon {
    switch (kind) {
      case ChatUploadKind.photo:
        return Icons.photo_camera_rounded;
      case ChatUploadKind.video:
        return Icons.videocam_rounded;
      case ChatUploadKind.document:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get _accent {
    switch (kind) {
      case ChatUploadKind.photo:
        return const Color(0xFFE91E8C);
      case ChatUploadKind.video:
        return const Color(0xFFFF6A3D);
      case ChatUploadKind.document:
        return const Color(0xFF5B6CFF);
    }
  }

  String get _title {
    switch (kind) {
      case ChatUploadKind.photo:
        return 'Sending photo';
      case ChatUploadKind.video:
        return 'Sending video';
      case ChatUploadKind.document:
        return 'Sending file';
    }
  }

  String get _subtitle {
    final name = fileName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.length > 36 ? '${name.substring(0, 33)}…' : name;
    }
    switch (kind) {
      case ChatUploadKind.photo:
        return 'Uploading and delivering…';
      case ChatUploadKind.video:
        return 'This may take a moment…';
      case ChatUploadKind.document:
        return 'Uploading attachment…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = kind == ChatUploadKind.document
        ? theme.colorScheme.primary
        : _accent;

    final cardBg = isDark
        ? const Color(0xFF1E1E24).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.85);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 280,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: accent,
                              backgroundColor: accent.withValues(alpha: 0.12),
                            ),
                          ),
                          Icon(_icon, color: accent, size: 26),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
