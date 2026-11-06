import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message_reaction.dart';

/// A horizontal row of grouped emoji-reaction chips that sits just below a
/// message bubble. Each chip shows the emoji and a count; tapping toggles the
/// current user's reaction.
class ReactionChipsRow extends StatelessWidget {
  final List<MessageReaction> reactions;
  final String currentUserId;
  final void Function(String emoji) onToggle;
  final bool alignEnd;

  const ReactionChipsRow({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onToggle,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    // Group by emoji
    final grouped = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      grouped.putIfAbsent(r.emoji, () => []).add(r);
    }
    final theme = Theme.of(context);
    final chips = grouped.entries.map((entry) {
      final emoji = entry.key;
      final count = entry.value.length;
      final mine = entry.value.any((r) => r.userId == currentUserId);
      return Padding(
        padding: const EdgeInsets.only(right: 4, top: 2),
        child: Material(
          color: mine
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : (theme.brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200]),
          shape: StadiumBorder(
            side: BorderSide(
              color: mine
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle(emoji);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  if (count > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        children: chips,
      ),
    );
  }
}
