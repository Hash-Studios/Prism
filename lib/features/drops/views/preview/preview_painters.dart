import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A diagonal repeating "PRISM DROP" mark. [opacity] scales its base alpha, so it can fade out.
class DropWatermarkPainter extends CustomPainter {
  const DropWatermarkPainter({required this.opacity, required this.label});

  final double opacity;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final TextPainter text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: PrismFonts.proximaNova,
          color: DropPalette.ink.withValues(alpha: 0.13 * opacity),
          fontSize: size.width * 0.075,
          fontWeight: FontWeight.w700,
          letterSpacing: size.width * 0.02,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double stepX = text.width + size.width * 0.12;
    final double stepY = size.width * 0.3;
    final double reach = size.longestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 7);
    int row = 0;
    for (double y = -reach; y < reach; y += stepY, row++) {
      final double shift = row.isEven ? 0 : stepX / 2;
      for (double x = -reach + shift; x < reach; x += stepX) {
        text.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DropWatermarkPainter oldDelegate) => oldDelegate.opacity != opacity || oldDelegate.label != label;
}

/// One gold sheen band sweeping the screen diagonally. [progress] runs 0 to 1 and paints nothing at either end.
class DropSheenPainter extends CustomPainter {
  const DropSheenPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final double band = size.width * 0.7;
    final double head = -band + progress * (size.width + 2 * band);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(head - band / 2, size.height * 0.62),
          Offset(head + band / 2, size.height * 0.38),
          <Color>[
            DropPalette.goldLight.withValues(alpha: 0),
            DropPalette.goldLight.withValues(alpha: 0.5),
            DropPalette.goldLight.withValues(alpha: 0),
          ],
          const <double>[0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(DropSheenPainter oldDelegate) => oldDelegate.progress != progress;
}
