import 'package:flutter/material.dart';
import '../../models/user_presence.dart';

/// Live "online" / "last seen X ago" subtitle driven by [UserPresence].
/// Safe to drop into an app bar title column or conversation tile.
class PresenceSubtitle extends StatelessWidget {
  final UserPresence? presence;
  final TextStyle? style;
  final bool showDot;
  /// Text to render when [presence] is `null` (no status received yet).
  final String? fallback;
  /// Master switch — when false, render only [fallback] (or nothing) and
  /// never show the green/grey dot or any online/last-seen text.
  /// Driven by the user's "Show online status" chat-settings toggle.
  final bool showPresence;
  /// When false and the peer is currently offline, render [fallback] instead
  /// of "last seen X ago". Online users still show "online" when
  /// [showPresence] is true. Driven by the "Show last seen" toggle.
  final bool showLastSeen;

  const PresenceSubtitle({
    super.key,
    required this.presence,
    this.style,
    this.showDot = true,
    this.fallback,
    this.showPresence = true,
    this.showLastSeen = true,
  });

  @override
  Widget build(BuildContext context) {
    // Privacy: when the local "Show online status" toggle is off, we render
    // only the fallback (or nothing) — never the dot or status text.
    final effectivePresence =
        showPresence ? presence : null;
    // Privacy: offline + "Show last seen" off → downgrade to fallback.
    final hideOfflineDetail = showPresence &&
        !showLastSeen &&
        presence != null &&
        !presence!.isOnline;
    if (effectivePresence == null || hideOfflineDetail) {
      if (fallback == null || fallback!.isEmpty) {
        return const SizedBox.shrink();
      }
      final theme = Theme.of(context);
      return Text(
        fallback!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style ??
            theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
            ),
      );
    }
    final theme = Theme.of(context);
    final isOnline = effectivePresence.isOnline;
    final effectiveStyle = style ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            effectivePresence.describe(),
            style: effectiveStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
