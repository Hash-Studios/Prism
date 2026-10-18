import 'dart:math' as math;

import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const int wheelBulbCount = 16;

/// Paints one bulb at [center]. [lit] runs from 0 (dim gold) to 1 (a near white core with a soft glow).
void paintBulb(Canvas canvas, Offset center, double radius, double lit, WheelGold gold) {
  final Color unlit = Color.lerp(gold.deep, gold.dark, 0.7)!;
  final Color core = gold.glint;
  canvas.drawCircle(center, radius * 1.38, Paint()..color = Color.lerp(gold.dark, gold.ink, 0.5)!);
  canvas.drawCircle(
    center,
    radius * 1.38,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.22
      ..color = gold.highlight.withValues(alpha: 0.28),
  );
  if (lit > 0.12) {
    final double glow = math.pow(lit, 1.6).toDouble();
    canvas.drawCircle(
      center,
      radius * 3.1,
      Paint()
        ..color = gold.base.withValues(alpha: 0.6 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.3),
    );
  }
  final Rect rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 0.95,
        colors: <Color>[Color.lerp(unlit, core, lit)!, Color.lerp(gold.dark, gold.base, lit)!],
      ).createShader(rect),
  );
  canvas.drawCircle(
    center.translate(-radius * 0.3, -radius * 0.34),
    radius * 0.24,
    Paint()..color = gold.glint.withValues(alpha: 0.28 + 0.4 * lit),
  );
}

/// The static part of the wheel: the soft shadow, the gold bezel with its bulbs and the dark ring inside it. It does
/// not turn. It repaints when [frame] changes, which is a bulb change, never a layout change.
class WheelBezelPainter extends CustomPainter {
  WheelBezelPainter({required this.geometry, required this.palette, required this.frame}) : super(repaint: frame);

  final WheelGeometry geometry;
  final WheelPalette palette;
  final ValueListenable<BulbFrame> frame;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double outer = geometry.radius;
    final double inner = outer - geometry.bezelWidth;
    final WheelGold gold = palette.gold;
    final Rect bounds = Rect.fromCircle(center: c, radius: outer);

    canvas.drawCircle(
      c.translate(0, geometry.diameter * 0.035),
      outer * 0.98,
      Paint()
        ..color = palette.colorScheme.scrim.withValues(alpha: palette.dark ? 0.55 : 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, geometry.diameter * 0.04),
    );

    final Path ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(bounds)
      ..addOval(Rect.fromCircle(center: c, radius: inner));
    canvas.drawPath(
      ring,
      Paint()
        ..shader = SweepGradient(
          colors: gold.metal,
          transform: const GradientRotation(-math.pi * 0.62),
        ).createShader(bounds),
    );
    canvas.drawCircle(
      c,
      outer - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = gold.dark.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      c,
      outer - geometry.diameter * 0.011,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geometry.diameter * 0.006
        ..shader = SweepGradient(
          colors: <Color>[
            gold.highlight.withValues(alpha: 0.2),
            gold.glint.withValues(alpha: 0.75),
            gold.highlight.withValues(alpha: 0.2),
            gold.highlight.withValues(alpha: 0.05),
            gold.highlight.withValues(alpha: 0.2),
          ],
          stops: const <double>[0, 0.12, 0.3, 0.7, 1],
          transform: const GradientRotation(-math.pi * 0.9),
        ).createShader(bounds),
    );
    canvas.drawCircle(
      c,
      inner + 0.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = gold.dark.withValues(alpha: 0.85),
    );

    final double ringOuter = inner;
    final Rect ringBounds = Rect.fromCircle(center: c, radius: ringOuter);
    canvas.drawCircle(
      c,
      ringOuter,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color.lerp(palette.ink, palette.shine, 0.12)!, palette.ink],
        ).createShader(ringBounds),
    );

    final BulbFrame bulbs = frame.value;
    const double step = 2 * math.pi / wheelBulbCount;
    for (int k = 0; k < wheelBulbCount; k++) {
      final double a = -math.pi / 2 + (k + 0.5) * step;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * geometry.bulbOrbit;
      paintBulb(canvas, p, geometry.bulbRadius, bulbs.intensity(k), gold);
    }
  }

  @override
  bool shouldRepaint(WheelBezelPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette.colorScheme != palette.colorScheme ||
      oldDelegate.frame != frame;
}
