import 'dart:math' as math;

import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The wheel face: one slice per segment, thin dark separators and a peg at every boundary. At angle 0 slice `i` starts
/// `i * s` clockwise from the top, where the pointer is.
class WheelFacePainter extends CustomPainter {
  const WheelFacePainter({
    required this.segments,
    required this.palette,
    required this.geometry,
    this.winner,
    this.dim = 0,
  });

  final List<WheelSegment> segments;
  final WheelPalette palette;
  final WheelGeometry geometry;

  /// The slice that stays bright when [dim] is above 0.
  final int? winner;

  /// 0 to 1. How far the other slices darken after a landing.
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double face = geometry.faceRadius;
    final int n = segments.length;
    final double s = 2 * math.pi / n;
    final List<Color> colors = palette.sliceColors(segments);
    final Rect rect = Rect.fromCircle(center: c, radius: face);
    for (int i = 0; i < n; i++) {
      final HSLColor hsl = HSLColor.fromColor(colors[i]);
      final Color centre = hsl.withLightness((hsl.lightness - 0.07).clamp(0.0, 1.0)).toColor();
      final Color rim = hsl.withLightness((hsl.lightness + 0.045).clamp(0.0, 1.0)).toColor();
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * s,
        s,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[centre, colors[i], rim],
            stops: const <double>[0.1, 0.62, 1],
          ).createShader(rect),
      );
    }

    // Separators and the soft shade at the rim.
    final Paint separator = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, geometry.diameter * 0.009)
      ..strokeCap = StrokeCap.round
      ..color = palette.ink.withValues(alpha: 0.9);
    for (int i = 0; i < n; i++) {
      final double a = -math.pi / 2 + i * s;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * geometry.hubRadius, c + dir * face, separator);
    }
    canvas.drawCircle(
      c,
      face,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[Colors.transparent, palette.ink.withValues(alpha: 0.42)],
          stops: const <double>[0.86, 1],
        ).createShader(rect),
    );

    if (winner != null && dim > 0) {
      final Paint shade = Paint()..color = palette.ink.withValues(alpha: 0.36 * dim);
      for (int i = 0; i < n; i++) {
        if (i == winner) continue;
        canvas.drawArc(rect, -math.pi / 2 + i * s, s, true, shade);
      }
    }

    final WheelGold gold = palette.gold;
    final int? win = winner;
    if (win != null && dim > 0) {
      // A gold line along the rim of the winning slice.
      canvas.drawArc(
        rect.deflate(geometry.diameter * 0.006),
        -math.pi / 2 + win * s + 0.02,
        s - 0.04,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = geometry.diameter * 0.009
          ..color = gold.glint.withValues(alpha: 0.9 * dim),
      );
    }

    // Pegs.
    final double pr = geometry.pegRadius;
    for (int i = 0; i < n; i++) {
      final double a = -math.pi / 2 + i * s;
      final Offset p = c + Offset(math.cos(a), math.sin(a)) * geometry.pegOrbit;
      canvas.drawCircle(p.translate(0, pr * 0.35), pr * 1.35, Paint()..color = palette.ink.withValues(alpha: 0.55));
      canvas.drawCircle(
        p,
        pr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: <Color>[gold.glint, gold.base, gold.deep],
            stops: const <double>[0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: p, radius: pr)),
      );
    }
  }

  @override
  bool shouldRepaint(WheelFacePainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.palette.colorScheme != palette.colorScheme ||
      oldDelegate.geometry != geometry ||
      oldDelegate.winner != winner ||
      oldDelegate.dim != dim;
}

/// The turning part of the wheel: the painted face with its labels. Put it in a `RepaintBoundary` and rotate it with a
/// `Transform`, so a frame changes only a matrix.
class WheelFace extends StatelessWidget {
  const WheelFace({
    super.key,
    required this.segments,
    required this.palette,
    required this.geometry,
    this.winner,
    this.dim = 0,
    this.showLabels = true,
  });

  final List<WheelSegment> segments;
  final WheelPalette palette;
  final WheelGeometry geometry;
  final int? winner;
  final double dim;

  /// False for the small wheel on the Rewards card, where a label would be noise.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final int n = segments.length;
    final List<Color> colors = palette.sliceColors(segments);
    final double s = 2 * math.pi / n;
    return SizedBox.square(
      dimension: geometry.diameter,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(
            painter: WheelFacePainter(
              segments: segments,
              palette: palette,
              geometry: geometry,
              winner: winner,
              dim: dim,
            ),
          ),
          if (showLabels)
            for (int i = 0; i < n; i++)
              Transform.rotate(
                angle: (i + 0.5) * s,
                child: _SliceLabelStrip(
                  segment: segments[i],
                  ink: palette.inkOn(colors[i]),
                  geometry: geometry,
                  count: n,
                  // The left half of the wheel reads towards the hub so its text is upright at rest.
                  towardsHub: (i + 0.5) * s > math.pi,
                ),
              ),
        ],
      ),
    );
  }
}

/// A slice label laid along the slice's radius, centred in its slice. The strip is a square the size of the wheel so
/// that rotating it about its centre puts the label on the right slice.
class _SliceLabelStrip extends StatelessWidget {
  const _SliceLabelStrip({
    required this.segment,
    required this.ink,
    required this.geometry,
    required this.count,
    required this.towardsHub,
  });

  final WheelSegment segment;
  final Color ink;
  final WheelGeometry geometry;
  final int count;
  final bool towardsHub;

  @override
  Widget build(BuildContext context) {
    final double inner = geometry.labelInner;
    final double outer = geometry.labelOuter;
    // The label's height is what the slice allows at its narrow, inner end.
    final double height = math.min(
      geometry.faceRadius * 0.3,
      geometry.labelWidthAt(inner + (outer - inner) * 0.25, count),
    );
    return SizedBox.square(
      dimension: geometry.diameter,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: geometry.radius - outer),
          child: SizedBox(
            width: height,
            height: outer - inner,
            child: RotatedBox(
              quarterTurns: towardsHub ? 1 : 3,
              child: SizedBox(
                width: outer - inner,
                height: height,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: WheelPrizeLabel(
                    prize: segment.prize,
                    ink: ink,
                    size: geometry.faceRadius * (_digits(segment.prize) > 2 ? 0.19 : 0.22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Digits in the number a prize shows.
int _digits(WheelPrize prize) => switch (prize) {
  CoinsPrize(:final int coins) => '$coins'.length,
  XpPrize(:final int xp) => '$xp'.length,
  CosmeticPrize() => 0,
};

/// What a slice pays, as it reads on the wheel: a coin and a number, a number and "XP", or a sparkle and "Mystery".
class WheelPrizeLabel extends StatelessWidget {
  const WheelPrizeLabel({super.key, required this.prize, required this.ink, required this.size});

  final WheelPrize prize;
  final Color ink;

  /// Height of the numeral.
  final double size;

  @override
  Widget build(BuildContext context) {
    final TextStyle numeral = PrismTextStyles.numeral(context, size).copyWith(color: ink, fontWeight: FontWeight.w700);
    final TextStyle word = PrismTextStyles.cardTitle(
      context,
    ).copyWith(fontSize: size * 0.5, color: ink, height: 1, letterSpacing: 0.4);
    final double gap = size * 0.14;
    final List<Widget> parts = switch (prize) {
      CoinsPrize(:final int coins) => <Widget>[
        PrismCoinIcon(size: size * 0.92),
        SizedBox(width: gap),
        Text('$coins', style: numeral),
      ],
      XpPrize(:final int xp) => <Widget>[Text('$xp', style: numeral), SizedBox(width: gap), Text('XP', style: word)],
      CosmeticPrize() => <Widget>[
        Icon(Icons.auto_awesome_rounded, size: size * 0.78, color: ink),
        SizedBox(width: gap),
        Text('Mystery', style: word.copyWith(fontSize: size * 0.66)),
      ],
    };
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}
