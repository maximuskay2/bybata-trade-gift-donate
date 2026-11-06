import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quick emoji picker displayed above a long-pressed message.
///
/// Shows 6 common emojis plus an optional "+" button for more. Returns the
/// selected emoji string via [Navigator.pop], or null if dismissed.
class ReactionPickerSheet extends StatelessWidget {
  /// Common reactions, ordered by frequency.
  static const defaultEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  /// Extended emoji set shown when the user taps the "+" button.
  static const extendedEmojis = [
    '👍', '❤️', '😂', '😮', '😢', '🙏',
    '🎉', '🔥', '👏', '💯', '😍', '🤔',
    '😊', '😅', '😎', '👌', '💪', '✨',
    '😡', '👎', '🤝', '🙌', '✅', '❌',
  ];

  final List<String> emojis;

  const ReactionPickerSheet({
    super.key,
    this.emojis = defaultEmojis,
  });

  /// Shows the picker as a modal bottom sheet. Resolves to the picked emoji,
  /// or `null` when dismissed.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: ReactionPickerSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      elevation: 8,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in emojis) _EmojiButton(emoji: e),
            _MoreButton(),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final String emoji;
  const _EmojiButton({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop(emoji);
      },
      iconSize: 28,
      icon: Text(emoji, style: const TextStyle(fontSize: 26)),
    );
  }
}

class _MoreButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ReactionPickerSheet.extendedEmojis
                    .map(
                      (e) => InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(ctx).pop(e);
                        },
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
        if (picked != null && context.mounted) {
          Navigator.of(context).pop(picked);
        }
      },
      icon: const Icon(Icons.add_circle_outline),
    );
  }
}
