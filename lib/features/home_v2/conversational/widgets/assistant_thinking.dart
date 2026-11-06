import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gemini-style "thinking" state shown while the answer is being prepared:
/// a pulsing sparkle, a shimmering status line that changes as it works, and
/// soft placeholder lines for the reply.
class AssistantThinking extends StatefulWidget {
  final List<String> phrases;

  const AssistantThinking({
    super.key,
    this.phrases = const [
      'Thinking…',
      'Reading what you need…',
      'Checking trades, gifts and campaigns…',
      'Putting your answer together…',
    ],
  });

  @override
  State<AssistantThinking> createState() => _AssistantThinkingState();
}

class _AssistantThinkingState extends State<AssistantThinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  Timer? _ticker;
  int _phrase = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      if (_phrase >= widget.phrases.length - 1) {
        _ticker?.cancel();
        return;
      }
      setState(() => _phrase += 1);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final phrase = widget.phrases[_phrase];

    return Semantics(
      liveRegion: true,
      label: phrase,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final t = reduceMotion ? 0.5 : _shimmer.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Sparkle(progress: t, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, if (current != null) current],
                      ),
                      child: _ShimmerText(
                        key: ValueKey(phrase),
                        text: phrase,
                        progress: t,
                        base: scheme.onSurface.withValues(alpha: 0.55),
                        highlight: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final width in const [0.92, 0.78, 0.55])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 34),
                  child: _ShimmerBar(
                    widthFactor: width,
                    progress: t,
                    base: scheme.onSurface.withValues(alpha: 0.06),
                    highlight: scheme.primary.withValues(alpha: 0.16),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double progress;
  final Color color;

  const _Sparkle({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(progress * 2 * math.pi);
    return Transform.rotate(
      angle: progress * 2 * math.pi * 0.25,
      child: Transform.scale(
        scale: 1 + wave * 0.08,
        child: ShaderMask(
          shaderCallback: (bounds) => SweepGradient(
            colors: [
              color,
              const Color(0xFF8E6CF6),
              const Color(0xFFE86AA6),
              color,
            ],
            transform: GradientRotation(progress * 2 * math.pi),
          ).createShader(bounds),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

LinearGradient _sweep(double progress, Color base, Color highlight) {
  final x = -1.5 + progress * 3;
  return LinearGradient(
    begin: Alignment(x - 1, 0),
    end: Alignment(x + 1, 0),
    colors: [base, highlight, base],
    stops: const [0.2, 0.5, 0.8],
  );
}

class _ShimmerText extends StatelessWidget {
  final String text;
  final double progress;
  final Color base;
  final Color highlight;

  const _ShimmerText({
    super.key,
    required this.text,
    required this.progress,
    required this.base,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          _sweep(progress, base, highlight).createShader(bounds),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double widthFactor;
  final double progress;
  final Color base;
  final Color highlight;

  const _ShimmerBar({
    required this.widthFactor,
    required this.progress,
    required this.base,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: _sweep(progress, base, highlight),
        ),
      ),
    );
  }
}
