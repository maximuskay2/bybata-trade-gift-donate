import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lightweight in-app emoji picker that avoids pulling in a new dependency.
///
/// Renders a categorized grid inside a modal bottom sheet. Tapping an emoji
/// inserts it at the current cursor position in the provided
/// [TextEditingController] without dismissing the sheet, so users can chain
/// multiple emojis.
class EmojiPickerSheet extends StatefulWidget {
  final TextEditingController controller;

  const EmojiPickerSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => EmojiPickerSheet(controller: controller),
    );
  }

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  static const Map<String, List<String>> _categories = {
    'Smileys': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
      '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
      '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
      '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
      '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤧', '🥵',
      '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐',
    ],
    'Gestures': [
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉',
      '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤝', '👏',
      '🙌', '🙏', '✊', '👊', '🤛', '🤜', '💪', '🦾', '🤌', '🤏',
    ],
    'Hearts': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '❤️‍🔥',
    ],
    'Objects': [
      '🔥', '✨', '🎉', '🎊', '🎁', '🎈', '💯', '💥', '💫', '⭐',
      '🌟', '🌈', '☀️', '🌙', '⚡', '☔', '❄️', '☕', '🍕', '🍔',
      '🍟', '🍿', '🍩', '🍰', '🎂', '🍫', '🍬', '🍎', '🍉', '🍓',
      '📱', '💻', '⌚', '📷', '🎵', '🎶', '⚽', '🏀', '🎮', '🚗',
    ],
  };

  String _active = 'Smileys';

  void _insert(String emoji) {
    HapticFeedback.selectionClick();
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final emojis = _categories[_active] ?? const <String>[];

    return FractionallySizedBox(
      heightFactor: 0.55,
      child: Column(
        children: [
          // Category tabs
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final name = _categories.keys.elementAt(i);
                final active = name == _active;
                return ChoiceChip(
                  label: Text(name),
                  selected: active,
                  onSelected: (_) => setState(() => _active = name),
                  selectedColor:
                      theme.colorScheme.primary.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 48,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) {
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _insert(emojis[i]),
                  child: Center(
                    child: Text(
                      emojis[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
