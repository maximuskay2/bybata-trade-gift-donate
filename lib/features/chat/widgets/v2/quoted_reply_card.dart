import 'package:flutter/material.dart';
import '../../models/reply_preview.dart';

/// Compact quoted-reply card.
///
/// Used in two places:
///   * Inside [MessageBubbleV2] above the main content to show "replying to".
///   * Above the composer (with a close button) when staging a new reply.
class QuotedReplyCard extends StatelessWidget {
  final ReplyPreview preview;
  final bool insideOwnBubble;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const QuotedReplyCard({
    super.key,
    required this.preview,
    this.insideOwnBubble = false,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        insideOwnBubble ? Colors.white : theme.colorScheme.primary;
    final bg = insideOwnBubble
        ? Colors.white.withValues(alpha: 0.15)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final nameColor = insideOwnBubble ? Colors.white : accent;
    final previewColor = insideOwnBubble
        ? Colors.white.withValues(alpha: 0.85)
        : (theme.textTheme.bodySmall?.color ?? Colors.black87)
            .withValues(alpha: 0.85);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    preview.senderName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: nameColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _previewBody(context, previewColor),
                ],
              ),
            ),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                icon: Icon(Icons.close, size: 16, color: previewColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewBody(BuildContext context, Color previewColor) {
    final type = preview.type.toUpperCase();
    IconData? icon;
    String text = preview.contentPreview;
    if (type == 'IMAGE') {
      icon = Icons.photo;
      if (text.isEmpty) text = 'Photo';
    } else if (type == 'VIDEO') {
      icon = Icons.videocam;
      if (text.isEmpty) text = 'Video';
    } else if (type == 'FILE') {
      icon = Icons.insert_drive_file;
      if (text.isEmpty) text = 'Attachment';
    } else if (type == 'VOICE') {
      icon = Icons.mic;
      if (text.isEmpty) text = 'Voice note';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: previewColor),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: previewColor,
                ),
          ),
        ),
      ],
    );
  }
}
