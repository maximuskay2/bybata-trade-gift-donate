import 'dart:async';

import 'package:flutter/material.dart';

/// One quiet rise-and-fade. Later items wait a little, then settle together.
/// Presentation-only — wrap chrome and headers, not primary action rows mid-tap.
class SoftReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final bool enabled;
  final double travel;

  const SoftReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.enabled = true,
    this.travel = 16,
  });

  @override
  State<SoftReveal> createState() => _SoftRevealState();
}

class _SoftRevealState extends State<SoftReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  Timer? _wait;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled || reduce) {
      _motion.value = 1;
      return;
    }
    final delay = widget.index.clamp(0, 7) * 46;
    if (delay == 0) {
      _motion.forward();
      return;
    }
    _wait = Timer(Duration(milliseconds: delay), () {
      if (mounted) _motion.forward();
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_motion.value);
        return IgnorePointer(
          ignoring: t < 0.2,
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * widget.travel),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
