import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fine interleaved sine lines, like the engraving on a banknote. Hairline strokes fade out towards the bottom end.
class GuillochePainter extends CustomPainter {
  const GuillochePainter({required this.color, this.lines = 26, this.phase = 0});

  final Color color;
  final int lines;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: <Color>[color, color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    final double step = size.width / 90;
    for (int i = 0; i < lines; i++) {
      final double t = i / lines;
      final double base = size.height * (0.1 + 0.9 * t);
      final Path path = Path();
      for (double x = 0; x <= size.width + step; x += step) {
        final double wave =
            math.sin(x / size.width * math.pi * 5 + t * math.pi * 2 + phase) * (6 + 14 * math.sin(t * math.pi));
        final double y = base + wave + math.sin(x / size.width * math.pi * 11 + i * 0.5) * 2;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(GuillochePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.lines != lines || oldDelegate.phase != phase;
}
