import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dark gather splash. Three hub lights orbit a mark. No wordmark.
class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final bool showLoadingIndicator;
  final Widget? overlay;

  const AnimatedSplashScreen({
    super.key,
    this.onComplete,
    this.showLoadingIndicator = true,
    this.overlay,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _flow.stop();
      _flow.value = 0.35;
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10141C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _flow,
              builder: (context, _) {
                return CustomPaint(
                  painter: _GatherFieldPainter(t: _flow.value),
                );
              },
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _flow,
              builder: (context, child) {
                final pulse = 0.5 + 0.5 * math.sin(_flow.value * math.pi * 2);
                return Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8C872).withValues(
                          alpha: 0.18 + 0.16 * pulse,
                        ),
                        blurRadius: 28 + 12 * pulse,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: ClipOval(
                child: Image.asset(
                  'assets/animations/logo.png',
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF1C2430),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFE8C872),
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showLoadingIndicator)
            const Align(
              alignment: Alignment(0, 0.62),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Trade. Gift. Donate and Grow Together',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: Color(0xD9FFFFFF),
                    height: 1.45,
                  ),
                ),
              ),
            ),
          if (widget.overlay != null) widget.overlay!,
        ],
      ),
    );
  }
}

class _GatherFieldPainter extends CustomPainter {
  final double t;

  const _GatherFieldPainter({required this.t});

  static const List<Color> _lights = [
    Color(0xFFE8C872),
    Color(0xFFFB7185),
    Color(0xFF34D399),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF10141C));
    final center = size.center(Offset.zero);
    final reach = math.min(size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1C2430), Color(0xFF10141C)],
          stops: [0.2, 0.78],
        ).createShader(Rect.fromCircle(center: center, radius: reach * 0.72)),
    );

    final orbit = reach * 0.29;
    final turn = t * math.pi * 2;
    for (var i = 0; i < _lights.length; i++) {
      final angle = turn + i * (math.pi * 2 / 3);
      final breathe = 1 + 0.045 * math.sin(turn * 2 + i);
      final point = center +
          Offset(math.cos(angle), math.sin(angle) * 0.86) * orbit * breathe;
      canvas.drawCircle(
        point,
        34,
        Paint()
          ..color = _lights[i].withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
      );
      canvas.drawCircle(point, 9, Paint()..color = _lights[i]);
    }

    canvas.drawCircle(
      center,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x55FFFFFF),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: orbit + 18),
      -math.pi / 2 + turn,
      math.pi * 0.72,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE8C872),
    );
  }

  @override
  bool shouldRepaint(_GatherFieldPainter oldDelegate) => oldDelegate.t != t;
}
