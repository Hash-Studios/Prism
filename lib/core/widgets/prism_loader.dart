import 'dart:ui' show PathMetric;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:flutter/material.dart';

/// The Prism mark drawn in three steps: the outline, the centre ridge, then the two facets in the accent colour.
/// [PrismLoader] loops the steps while something loads. [PrismLoader.progress] shows the steps for a value from 0 to 1,
/// for example a pull distance. With reduce motion on, the looping loader holds the finished mark.
class PrismLoader extends StatefulWidget {
  const PrismLoader({super.key, this.size = 28}) : progress = null;

  const PrismLoader.progress(double this.progress, {super.key, this.size = 28});

  /// Null loops. Otherwise 0 shows nothing, 1/3 the outline, 2/3 the ridge, 1 the filled mark.
  final double? progress;
  final double size;

  @override
  State<PrismLoader> createState() => _PrismLoaderState();
}

class _PrismLoaderState extends State<PrismLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: PrismDurations.shimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PrismLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.progress == null && !context.reduceMotion) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double? progress = widget.progress;
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: progress != null || context.reduceMotion
            ? CustomPaint(
                painter: PrismMarkPainter(t: progress ?? 1, ink: cs.onSurface, fill: cs.primary),
              )
            : AnimatedBuilder(
                animation: _loop,
                builder: (context, _) {
                  // Build the mark over 75 % of the loop, hold it, then fade it out for the next pass.
                  final double v = _loop.value;
                  return CustomPaint(
                    painter: PrismMarkPainter(
                      t: PrismCurves.enter.transform((v / 0.75).clamp(0, 1)),
                      opacity: v < 0.88 ? 1 : 1 - (v - 0.88) / 0.12,
                      ink: cs.onSurface,
                      fill: cs.primary,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Paints the Prism mark (the kite in `prismVector`, 14 by 16) up to step [t].
class PrismMarkPainter extends CustomPainter {
  const PrismMarkPainter({required this.t, required this.ink, required this.fill, this.opacity = 1});

  final double t;
  final double opacity;
  final Color ink;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || opacity <= 0) return;
    final double h = size.height * 0.82;
    final double w = h * 14 / 16;
    final Offset o = Offset((size.width - w) / 2, (size.height - h) / 2);
    Offset p(double x, double y) => o + Offset(x / 14 * w, y / 15.13 * h);
    final Offset apex = p(7, 0);
    final Offset right = p(14, 12.12);
    final Offset bottom = p(7, 15.13);
    final Offset left = p(0, 12.12);

    final double outline = (t * 3).clamp(0, 1);
    final double ridge = (t * 3 - 1).clamp(0, 1);
    final double facets = (t * 3 - 2).clamp(0, 1);

    if (facets > 0) {
      final Paint face = Paint()..color = fill.withValues(alpha: fill.a * facets * opacity);
      canvas.drawPath(Path()..addPolygon(<Offset>[apex, bottom, left], true), face);
      face.color = fill.withValues(alpha: fill.a * facets * opacity * 0.6);
      canvas.drawPath(Path()..addPolygon(<Offset>[apex, right, bottom], true), face);
    }

    final Paint line = Paint()
      ..color = ink.withValues(alpha: ink.a * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path kite = Path()..addPolygon(<Offset>[apex, right, bottom, left], true);
    if (outline >= 1) {
      canvas.drawPath(kite, line);
    } else {
      final PathMetric metric = kite.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * outline), line);
    }
    if (ridge > 0) canvas.drawLine(apex, Offset.lerp(apex, bottom, ridge)!, line);
  }

  @override
  bool shouldRepaint(PrismMarkPainter old) =>
      old.t != t || old.opacity != opacity || old.ink != ink || old.fill != fill;
}
