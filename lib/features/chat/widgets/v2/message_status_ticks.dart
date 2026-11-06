import 'package:flutter/material.dart';
import '../../models/tick_status.dart';

/// WhatsApp-style message status ticks.
///
/// * [TickStatus.sent]      → 1 grey tick (server received)
/// * [TickStatus.delivered] → 2 grey ticks (recipient device received)
/// * [TickStatus.read]      → 2 theme-colored ticks (recipient opened)
/// * [TickStatus.none]      → nothing (incoming msg or pre-send)
class MessageStatusTicks extends StatelessWidget {
  final TickStatus status;
  final double size;
  final Color? readColor;
  final Color? greyColor;

  const MessageStatusTicks({
    super.key,
    required this.status,
    this.size = 14,
    this.readColor,
    this.greyColor,
  });

  @override
  Widget build(BuildContext context) {
    if (status == TickStatus.none) return const SizedBox.shrink();
    final grey = greyColor ?? Colors.white.withValues(alpha: 0.75);
    final read = readColor ?? Theme.of(context).colorScheme.primary;

    final color = status == TickStatus.read ? read : grey;

    if (status == TickStatus.sent) {
      return Icon(Icons.check, size: size, color: color);
    }
    // delivered / read → double tick
    return SizedBox(
      width: size + 6,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Icon(Icons.check, size: size, color: color),
          ),
          Positioned(
            left: 5,
            child: Icon(Icons.check, size: size, color: color),
          ),
        ],
      ),
    );
  }
}
