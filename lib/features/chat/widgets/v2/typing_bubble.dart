import 'package:flutter/material.dart';

/// Animated 3-dot bubble displayed when the other participant is typing.
class TypingBubble extends StatefulWidget {
  final String? label;
  final Color? bubbleColor;
  final Color? dotColor;

  const TypingBubble({
    super.key,
    this.label,
    this.bubbleColor,
    this.dotColor,
  });

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = widget.bubbleColor ??
        (theme.brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200]);
    final dot = widget.dotColor ?? theme.colorScheme.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubble,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.label != null) ...[
                Text(
                  widget.label!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              _Dot(controller: _controller, phase: 0.0, color: dot),
              const SizedBox(width: 3),
              _Dot(controller: _controller, phase: 0.2, color: dot),
              const SizedBox(width: 3),
              _Dot(controller: _controller, phase: 0.4, color: dot),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double phase;
  final Color color;

  const _Dot({
    required this.controller,
    required this.phase,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Shift value by phase and take a sin-like bounce between 0.3 and 1.0.
        final t = (controller.value + phase) % 1.0;
        final bounce = (t < 0.5) ? t * 2 : (1 - t) * 2;
        final opacity = 0.3 + (0.7 * bounce);
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
