import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A slow violet field. Light drifts, a bloom breathes, and gold rings open and fade.
class RadiantFieldPainter extends CustomPainter {
  final double t;

  const RadiantFieldPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8E63E0),
            Color(0xFF4A1C86),
            Color(0xFF14081F),
          ],
        ).createShader(rect),
    );

    final breathe = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final width = size.width;
    final height = size.height;

    void orb(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    orb(
      Offset(
        width * (0.5 + 0.06 * math.sin(t * math.pi * 2)),
        height * (0.38 + 0.025 * math.cos(t * math.pi * 2)),
      ),
      size.shortestSide * (0.58 + 0.05 * breathe),
      const Color(0x66FFFFFF),
    );
    orb(
      Offset(
        width * (0.16 + 0.05 * math.cos(t * math.pi * 2 + 0.8)),
        height * (0.2 + 0.035 * math.sin(t * math.pi * 2)),
      ),
      size.shortestSide * 0.4,
      const Color(0x73E8C872),
    );
    orb(
      Offset(
        width * (0.84 + 0.04 * math.sin(t * math.pi * 2 + 1.4)),
        height * (0.58 + 0.03 * math.cos(t * math.pi * 2)),
      ),
      size.shortestSide * 0.34,
      const Color(0x559333EA),
    );
    orb(
      Offset(width * 0.48, height * (0.9 + 0.02 * math.sin(t * math.pi * 2))),
      size.shortestSide * 0.46,
      const Color(0x4010B981),
    );

    final center = Offset(width / 2, height * 0.42);
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = size.shortestSide * (0.16 + 0.46 * phase);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 + (1 - phase) * 1.8
          ..color = const Color(0xFFE8C872).withValues(alpha: (1 - phase) * 0.5),
      );
    }

    for (var i = 0; i < 12; i++) {
      final angle = t * math.pi * 2 * (0.65 + (i % 3) * 0.15) + i * 0.85;
      final orbit = size.shortestSide * (0.18 + (i % 5) * 0.055);
      final point = center + Offset(math.cos(angle) * orbit, math.sin(angle) * orbit * 0.62);
      canvas.drawCircle(
        point,
        1.1 + (i % 3) * 0.55,
        Paint()..color = Color.fromRGBO(255, 255, 255, 0.35 + (i % 4) * 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadiantFieldPainter oldDelegate) => oldDelegate.t != t;
}
