import 'dart:math' as math;

import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The gold flapper at the top of the wheel. It pivots at its top and its tip rests against the pegs. [angle] is the
/// swing in radians, positive along the spin direction.
class WheelPointerPainter extends CustomPainter {
  WheelPointerPainter({required this.geometry, required this.palette, required this.angle}) : super(repaint: angle);

  final WheelGeometry geometry;
  final WheelPalette palette;
  final ValueListenable<double> angle;

  /// Where the pivot sits above the wheel's centre.
  static double pivotOffset(WheelGeometry g) => g.radius + g.diameter * 0.012;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final WheelGold gold = palette.gold;
    final double d = geometry.diameter;
    final double cap = d * 0.043;
    final Offset pivot = c.translate(0, -pivotOffset(geometry));
    final double length = pivotOffset(geometry) - geometry.tipRadius;

    // Positive swing carries the tip along the spin direction, to the right at the top of the wheel. That is a
    // counter-clockwise turn of the flapper about its pivot.
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-angle.value);

    final Path body = Path()
      ..moveTo(-cap, 0)
      ..arcToPoint(Offset(cap, 0), radius: Radius.circular(cap))
      ..cubicTo(cap, length * 0.42, cap * 0.38, length * 0.8, 0, length)
      ..cubicTo(-cap * 0.38, length * 0.8, -cap, length * 0.42, -cap, 0)
      ..close();
    final Rect bounds = Rect.fromLTRB(-cap, -cap, cap, length);
    canvas.drawPath(
      body.shift(Offset(0, d * 0.012)),
      Paint()
        ..color = palette.colorScheme.scrim.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.01),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[gold.deep, gold.highlight, gold.base, gold.deep],
          stops: const <double>[0, 0.32, 0.62, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, d * 0.006)
        ..strokeJoin = StrokeJoin.round
        ..color = gold.dark.withValues(alpha: 0.85),
    );
    // A bright edge on the left, where the light falls.
    canvas.drawPath(
      Path()
        ..moveTo(-cap * 0.62, cap * 0.2)
        ..quadraticBezierTo(-cap * 0.58, length * 0.5, -cap * 0.1, length * 0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1, d * 0.005)
        ..color = gold.glint.withValues(alpha: 0.8),
    );
    // The pivot.
    final Offset hinge = Offset(0, cap * 0.05);
    canvas.drawCircle(hinge, cap * 0.46, Paint()..color = gold.dark);
    canvas.drawCircle(
      hinge,
      cap * 0.34,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: <Color>[gold.glint, gold.base, gold.deep],
          stops: const <double>[0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: hinge, radius: cap * 0.34)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(WheelPointerPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette.colorScheme != palette.colorScheme ||
      oldDelegate.angle != angle;
}

/// The static hub in the middle of the wheel: a raised disc with a bevel and the coin.
class WheelHub extends StatelessWidget {
  const WheelHub({super.key, required this.geometry, required this.palette});

  final WheelGeometry geometry;
  final WheelPalette palette;

  @override
  Widget build(BuildContext context) {
    final double r = geometry.hubRadius;
    return SizedBox.square(
      dimension: r * 2,
      child: CustomPaint(
        painter: _HubPainter(palette: palette),
        child: Center(child: PrismCoinIcon(size: r * 1.12)),
      ),
    );
  }
}

class _HubPainter extends CustomPainter {
  const _HubPainter({required this.palette});

  final WheelPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final WheelGold gold = palette.gold;
    final Rect bounds = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c.translate(0, r * 0.14),
      r,
      Paint()
        ..color = palette.colorScheme.scrim.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
    );
    // Gold collar.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: gold.metal,
          transform: const GradientRotation(-math.pi * 0.62),
        ).createShader(bounds),
    );
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = gold.dark.withValues(alpha: 0.8),
    );
    // The raised disc.
    final double inner = r * 0.76;
    final Rect innerBounds = Rect.fromCircle(center: c, radius: inner);
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: <Color>[
            Color.lerp(palette.colorScheme.surfaceContainerHighest, palette.shine, 0.18)!,
            palette.colorScheme.surfaceContainerHigh,
            Color.lerp(palette.colorScheme.surface, palette.ink, 0.4)!,
          ],
          stops: const <double>[0, 0.55, 1],
        ).createShader(innerBounds),
    );
    canvas.drawCircle(
      c,
      inner - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[gold.glint.withValues(alpha: 0.7), gold.dark.withValues(alpha: 0.6)],
        ).createShader(innerBounds),
    );
  }

  @override
  bool shouldRepaint(_HubPainter oldDelegate) => oldDelegate.palette.colorScheme != palette.colorScheme;
}
