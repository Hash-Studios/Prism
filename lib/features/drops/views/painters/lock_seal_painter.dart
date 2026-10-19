import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small engraved round seal with a keyhole. [struck] draws a line through it, for a Drop that was missed.
class LockSealPainter extends CustomPainter {
  const LockSealPainter({required this.color, required this.fill, this.struck = false});

  final Color color;
  final Color fill;
  final bool struck;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = fill);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04 + 0.4
      ..color = color;
    canvas.drawCircle(c, r - 0.5, line);
    canvas.drawCircle(c, r * 0.8, line..color = color.withValues(alpha: 0.6));
    final Paint tick = Paint()
      ..strokeWidth = 0.6
      ..color = color.withValues(alpha: 0.7);
    for (int i = 0; i < 36; i++) {
      final double a = i * math.pi / 18;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r * 0.8), c + dir * (r * 0.9), tick);
    }
    final Paint solid = Paint()..color = color;
    canvas.drawCircle(c.translate(0, -r * 0.1), r * 0.15, solid);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.07, c.dy - r * 0.05)
        ..lineTo(c.dx + r * 0.07, c.dy - r * 0.05)
        ..lineTo(c.dx + r * 0.13, c.dy + r * 0.3)
        ..lineTo(c.dx - r * 0.13, c.dy + r * 0.3)
        ..close(),
      solid,
    );
    if (struck) {
      canvas.drawLine(
        c + Offset(-r * 0.55, r * 0.55),
        c + Offset(r * 0.55, -r * 0.55),
        Paint()
          ..color = color
          ..strokeWidth = r * 0.07
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(LockSealPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill || oldDelegate.struck != struck;
}
