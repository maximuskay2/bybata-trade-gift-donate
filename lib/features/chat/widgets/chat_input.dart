import 'package:flutter/material.dart';
import '../../../core/widgets/shadow_card.dart';
import '../../../core/theme/shadow_styles.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final VoidCallback? onImageTap;

  const ChatInput({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.hintText = 'Type a message...',
    this.onImageTap,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      shadowIntensity: _isFocused ? ShadowIntensity.medium : ShadowIntensity.light,
      borderRadius: 24,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.white,
      border: _isFocused
          ? Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              width: 2,
            )
          : null,
      child: Row(
        children: [
          // Image attachment button
          if (widget.onImageTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                onPressed: widget.onImageTap,
                icon: Icon(
                  Icons.image,
                  color: Colors.grey[600],
                  size: 20,
                ),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          
          // Text input
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onSubmitted: widget.onSubmitted,
              maxLines: null,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
          
          // Emoji button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => _showEmojiPicker(),
              icon: Icon(
                Icons.emoji_emotions_outlined,
                color: Colors.grey[600],
                size: 20,
              ),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 250,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Quick Emojis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                '😊', '👍', '❤️', '😂', '🎉', '👏', '🔥', '💯',
                '😍', '🙏', '👌', '✨', '😢', '😮', '🤔', '💪',
              ].map((emoji) => GestureDetector(
                onTap: () {
                  widget.controller.text += emoji;
                  Navigator.pop(context);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}