import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Size presets for the animated BYBATA wordmark loader.
enum BybataLoadingSize {
  /// Inline / dialog — ~15px letters
  compact(15, 2.0),

  /// Default section & screen loading — ~24px letters
  medium(24, 5.0),

  /// Splash & hero loading — ~36px letters (matches splash screen)
  large(36, 8.0);

  const BybataLoadingSize(this.fontSize, this.letterGap);
  final double fontSize;
  final double letterGap;
}

/// Animated "BYBATA" wordmark used as the app-wide loading throbber.
///
/// Each letter pulses in a traveling wave — scales, lifts, and brightens in
/// sequence so the brand name itself reads as the spinner.
class BybataLoadingIndicator extends StatefulWidget {
  const BybataLoadingIndicator({
    super.key,
    this.size = BybataLoadingSize.medium,
    this.fontSize,
    this.color,
    this.highlightColor,
    this.letterGap,
  });

  final BybataLoadingSize size;
  final double? fontSize;
  final Color? color;
  final Color? highlightColor;
  final double? letterGap;

  @override
  State<BybataLoadingIndicator> createState() => _BybataLoadingIndicatorState();
}

class _BybataLoadingIndicatorState extends State<BybataLoadingIndicator>
    with SingleTickerProviderStateMixin {
  static const _letters = ['B', 'Y', 'B', 'A', 'T', 'A'];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _wave(int index) {
    final phase = (_controller.value * 2 * math.pi) + (index * 2 * math.pi / _letters.length);
    return (math.sin(phase) + 1) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = widget.color ?? AppTheme.primaryColor;
    final peakColor = widget.highlightColor ?? _defaultHighlight(baseColor, scheme);
    final fontSize = widget.fontSize ?? widget.size.fontSize;
    final gap = widget.letterGap ?? widget.size.letterGap;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < _letters.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _AnimatedLetter(
                letter: _letters[i],
                wave: _wave(i),
                fontSize: fontSize,
                baseColor: baseColor,
                peakColor: peakColor,
              ),
            ],
          ],
        );
      },
    );
  }

  Color _defaultHighlight(Color base, ColorScheme scheme) {
    if (base == Colors.white || base.computeLuminance() > 0.85) {
      return Colors.white;
    }
    return Color.lerp(base, scheme.brightness == Brightness.dark ? Colors.white : base, 0.35)!;
  }
}

class _AnimatedLetter extends StatelessWidget {
  const _AnimatedLetter({
    required this.letter,
    required this.wave,
    required this.fontSize,
    required this.baseColor,
    required this.peakColor,
  });

  final String letter;
  final double wave;
  final double fontSize;
  final Color baseColor;
  final Color peakColor;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(baseColor.withValues(alpha: 0.35), peakColor, wave)!;
    final lift = 5.0 * wave;
    final scale = 0.76 + (0.24 * wave);

    return Transform.translate(
      offset: Offset(0, -lift),
      child: Transform.scale(
        scale: scale,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1,
            color: color,
            shadows: wave > 0.65
                ? [
                    Shadow(
                      color: peakColor.withValues(alpha: 0.35 * wave),
                      blurRadius: 12 * wave,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

/// Centered BYBATA loader with optional caption — drop-in for loading screens.
class BybataLoader extends StatelessWidget {
  const BybataLoader({
    super.key,
    this.message,
    this.subMessage,
    this.size = BybataLoadingSize.medium,
    this.color,
    this.highlightColor,
  });

  final String? message;
  final String? subMessage;
  final BybataLoadingSize size;
  final Color? color;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BybataLoadingIndicator(
              size: size,
              color: color,
              highlightColor: highlightColor,
            ),
            if (message != null) ...[
              SizedBox(height: size == BybataLoadingSize.large ? 28 : 20),
              Text(
                message!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.85),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
