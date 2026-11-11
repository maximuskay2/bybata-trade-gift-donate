import 'package:flutter/material.dart';

import '../utils/haptic_utils.dart';

/// Swipe-down math shared by the control and the tests.
abstract final class SwipeCommit {
  static const double threshold = 72;

  static bool shouldCommit(
    double dy, {
    double threshold = SwipeCommit.threshold,
  }) {
    return dy >= threshold;
  }

  /// A short drag springs back to zero. A long drag keeps its travel.
  static double releasedTravel(double dy) => shouldCommit(dy) ? dy : 0;
}

/// Runs [action] once until it finishes. A second call while busy is ignored.
class SwipeCommitGate {
  bool _busy = false;
  int fires = 0;

  bool get busy => _busy;

  Future<T?> run<T>(Future<T?> Function() action) async {
    if (_busy) return null;
    _busy = true;
    fires += 1;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }
}

/// Bottom commit CTA. Defaults to tap-only; optional swipe handle for tests/legacy.
class SwipeCommitControl extends StatefulWidget {
  final String label;
  final Future<void> Function() onCommit;
  final ValueChanged<double>? onTravel;
  final bool busy;
  final Color accent;
  final bool showHandle;
  /// White fill with [accent] label — for hub-colored bars.
  final bool inverted;

  const SwipeCommitControl({
    super.key,
    required this.label,
    required this.onCommit,
    this.onTravel,
    this.busy = false,
    this.accent = Colors.black,
    this.showHandle = false,
    this.inverted = false,
  });

  @override
  State<SwipeCommitControl> createState() => _SwipeCommitControlState();
}

class _SwipeCommitControlState extends State<SwipeCommitControl>
    with TickerProviderStateMixin {
  final SwipeCommitGate _gate = SwipeCommitGate();
  double _dy = 0;
  bool _armed = false;
  late final AnimationController _spring;
  late final AnimationController _pulse;

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!widget.showHandle) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _fire() async {
    if (widget.busy) return;
    await _gate.run(() async {
      HapticUtils.medium();
      await widget.onCommit();
      return true;
    });
  }

  void _setTravel(double dy) {
    final next = dy;
    final crossed = SwipeCommit.shouldCommit(next);
    if (crossed && !_armed) {
      _armed = true;
      HapticUtils.selection();
    } else if (!crossed) {
      _armed = false;
    }
    setState(() => _dy = next);
    widget.onTravel?.call(dy);
  }

  void _springBack() {
    final from = _dy;
    _armed = false;
    if (_reduce || from == 0) {
      _setTravel(0);
      return;
    }
    final animation = Tween<double>(
      begin: from,
      end: 0,
    ).animate(CurvedAnimation(parent: _spring, curve: Curves.easeOutBack));
    void tick() => _setTravel(animation.value);
    animation.addListener(tick);
    _spring.forward(from: 0).whenComplete(() {
      animation.removeListener(tick);
      _setTravel(0);
    });
  }

  /// Soft rubber-band past the commit threshold.
  double _displayTravel(double raw) {
    if (raw <= SwipeCommit.threshold) return raw;
    final over = raw - SwipeCommit.threshold;
    return SwipeCommit.threshold + over * 0.42;
  }

  @override
  Widget build(BuildContext context) {
    final drop = _reduce ? 0.0 : _displayTravel(_dy).clamp(0, 120);
    final progress = (_dy / SwipeCommit.threshold).clamp(0.0, 1.2);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHandle)
          GestureDetector(
            key: const Key('swipe-commit-handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              if (widget.busy || _gate.busy) return;
              final next = (_dy + details.delta.dy).clamp(0, 180).toDouble();
              if (_reduce) {
                _dy = next;
                return;
              }
              _setTravel(next);
            },
            onVerticalDragEnd: (_) {
              final travel = _dy;
              if (SwipeCommit.shouldCommit(travel)) {
                _setTravel(0);
                _fire();
              } else {
                _springBack();
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Transform.translate(
                offset: Offset(0, drop * 0.4),
                child: Transform.scale(
                  scale: 1 + (progress.clamp(0.0, 1.0) * 0.06),
                  child: Column(
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: widget.accent.withValues(
                          alpha: 0.55 + 0.45 * progress.clamp(0.0, 1.0),
                        ),
                        size: 26,
                      ),
                      Text(
                        progress >= 1 ? 'Release to send' : 'Swipe down',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: widget.accent.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = widget.showHandle || _reduce
                ? 0.0
                : 0.12 + 0.18 * _pulse.value;
            final glowColor =
                widget.inverted ? Colors.white : widget.accent;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: glow),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('swipe-commit-button'),
              onPressed: widget.busy || _gate.busy ? null : _fire,
              style: FilledButton.styleFrom(
                backgroundColor:
                    widget.inverted ? Colors.white : widget.accent,
                foregroundColor:
                    widget.inverted ? widget.accent : Colors.white,
                minimumSize: const Size.fromHeight(54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: widget.busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: widget.inverted
                            ? widget.accent
                            : Colors.white,
                      ),
                    )
                  : Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
