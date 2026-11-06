import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_message.dart';
import '../../utils/chat_message_utils.dart';
import '../voice_note_bubble.dart';
import 'chat_media_attachments.dart';
import 'document_bubble.dart';
import 'item_context_card.dart';
import 'message_status_ticks.dart';
import 'quoted_reply_card.dart';
import 'reaction_chips_row.dart';
import 'reaction_picker_sheet.dart';

/// WhatsApp-style message bubble with:
///   • swipe-to-reply (horizontal drag)
///   • long-press emoji reaction picker
///   • embedded quoted-reply card
///   • tick status indicator (1/2 grey, 2 theme-colored when read)
///   • grouped reaction chips below bubble
///   • support for text / image / voice / file / system types
class MessageBubbleV2 extends StatefulWidget {
  final ChatMessage message;
  final String currentUserId;
  final Color bubbleColor;
  final bool showSenderName;
  final VoidCallback? onSwipeReply;
  final void Function(String emoji)? onReactionSelected;
  final void Function(String emoji)? onReactionToggled;
  final VoidCallback? onQuotedTap;
  final Widget? imageWidget;

  /// Invoked when the user taps a SYSTEM item-context card. Receives the raw
  /// message metadata so the host (chat screen) can resolve {sourceType, itemId}
  /// and open the appropriate details screen.
  final void Function(Map<String, dynamic> metadata)? onItemContextTap;

  /// Accent for the "read" status tick; defaults to the app theme when omitted.
  final Color? moduleAccentColor;

  /// When true this bubble is visually chained to the previous one from the
  /// same sender — we tighten vertical spacing and skip the sender-name
  /// header to match WhatsApp's grouped appearance.
  final bool isGroupedWithPrevious;

  const MessageBubbleV2({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.bubbleColor,
    this.showSenderName = false,
    this.onSwipeReply,
    this.onReactionSelected,
    this.onReactionToggled,
    this.onQuotedTap,
    this.imageWidget,
    this.onItemContextTap,
    this.moduleAccentColor,
    this.isGroupedWithPrevious = false,
  });

  @override
  State<MessageBubbleV2> createState() => _MessageBubbleV2State();
}

class _MessageBubbleV2State extends State<MessageBubbleV2>
    with SingleTickerProviderStateMixin {
  double _dragX = 0.0;
  static const double _swipeThreshold = 60.0;

  Future<void> _handleLongPress() async {
    HapticFeedback.mediumImpact();
    if (widget.onReactionSelected == null) return;
    final picked = await ReactionPickerSheet.show(context);
    if (picked != null) widget.onReactionSelected!(picked);
  }

  bool get _isMe => isMessageFromMe(widget.message, widget.currentUserId);

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      // Allow swipe in the direction opposite to the sender side.
      final delta = d.primaryDelta ?? 0;
      if (_isMe) {
        _dragX = (_dragX + delta).clamp(-_swipeThreshold * 1.5, 0.0);
      } else {
        _dragX = (_dragX + delta).clamp(0.0, _swipeThreshold * 1.5);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_dragX.abs() >= _swipeThreshold) {
      HapticFeedback.selectionClick();
      widget.onSwipeReply?.call();
    }
    setState(() => _dragX = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isMe = _isMe;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Render structured item-context (first message of a listing thread) as a
    // dedicated tap-to-view card instead of a normal bubble, so both parties
    // always see the full listing preview.
    if (msg.messageType == MessageType.system &&
        (msg.metadata?['kind']?.toString() ?? '') == 'item_context') {
      final meta = Map<String, dynamic>.from(msg.metadata ?? const {});
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Align(
          alignment: Alignment.center,
          child: ItemContextCard(
            metadata: meta,
            isMe: isMe,
            onTap: widget.onItemContextTap == null
                ? null
                : () => widget.onItemContextTap!(meta),
          ),
        ),
      );
    }

    final otherBg = isDark ? Colors.grey[850] : Colors.grey[100];
    final bg = isMe ? widget.bubbleColor : otherBg;
    final textColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    final bodyWidget = _buildBody(context, textColor);
    final isMedia = msg.messageType == MessageType.image ||
        msg.messageType == MessageType.video;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMe ? 16 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 16),
    );

    // ClipRRect lets images render flush with the bubble corners (edge-to-edge
    // media) while the outer Container still paints the background + maxWidth
    // constraint.
    final bubble = ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(color: bg, borderRadius: borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showSenderName &&
                !isMe &&
                !widget.isGroupedWithPrevious)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                child: Text(
                  msg.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            if (msg.replyTo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: QuotedReplyCard(
                  preview: msg.replyTo!,
                  insideOwnBubble: isMe,
                  onTap: widget.onQuotedTap,
                ),
              ),
            // Image / video bodies render edge-to-edge; text / voice / file bodies
            // keep the usual inset so content breathes inside the bubble.
            if (isMedia)
              bodyWidget
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 0),
                child: bodyWidget,
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, isMedia ? 6 : 4, 10, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    MessageStatusTicks(
                      status: msg.tickStatus,
                      size: 13,
                      readColor: widget.moduleAccentColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final row = GestureDetector(
      onLongPress: _handleLongPress,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(_dragX, 0, 0),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: bubble,
            ),
            if (msg.reactions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: isMe ? 0 : 12,
                  right: isMe ? 12 : 0,
                ),
                child: ReactionChipsRow(
                  reactions: msg.reactions,
                  currentUserId: widget.currentUserId,
                  alignEnd: isMe,
                  onToggle: (e) => widget.onReactionToggled?.call(e),
                ),
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Stack(
        children: [
          // Reply hint icon revealed by swipe
          if (_dragX.abs() > 10)
            Positioned.fill(
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.reply,
                    size: 20,
                    color: theme.colorScheme.primary.withValues(
                      alpha: (_dragX.abs() / _swipeThreshold).clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),
            ),
          row,
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, Color textColor) {
    final msg = widget.message;
    switch (msg.messageType) {
      case MessageType.image:
        final key = msg.mediaStorageKey;
        if (key != null && key.isNotEmpty) {
          return ChatImageAttachment(storageKey: key);
        }
        return widget.imageWidget ??
            const SizedBox(
              width: 200,
              height: 120,
              child: _ImageFallback(),
            );
      case MessageType.video:
        final key = msg.mediaStorageKey;
        if (key != null && key.isNotEmpty) {
          return ChatVideoAttachment(
            storageKey: key,
            fileName: msg.documentName,
          );
        }
        return SizedBox(
          width: 200,
          height: 120,
          child: Center(
            child: Icon(Icons.videocam_off_rounded,
                color: textColor.withValues(alpha: 0.5)),
          ),
        );
      case MessageType.voice:
        return VoiceNoteBubble(
          message: msg,
          primaryColor: widget.bubbleColor,
          isMe: _isMe,
          isDark: Theme.of(context).brightness == Brightness.dark,
        );
      case MessageType.file:
        return DocumentBubble(
          message: msg,
          isMe: _isMe,
          isDark: Theme.of(context).brightness == Brightness.dark,
        );
      case MessageType.system:
        return Text(
          msg.message,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: textColor.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        );
      default:
        return Text(
          msg.message,
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }

  String _formatTime(DateTime ts) {
    final h = ts.hour;
    final m = ts.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$dh:$m $period';
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.image_outlined));
}
