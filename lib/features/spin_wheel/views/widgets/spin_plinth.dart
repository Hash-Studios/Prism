import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_bezel.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Metrics of the plinth, shared by the painter and the page that places things on it.
abstract final class PlinthMetrics {
  /// Height of the part below the wheel's bottom edge.
  static const double visibleHeight = 152;

  /// Gap between the wheel and the inner panel, and between the panel and the slab's edge.
  static const double panelGap = 8;
  static const double panelInset = 14;

  /// Where the three lights on each side sit, from the slab's edge.
  static const double lightInset = 32;
  static const double lightSpacing = 22;
  static const double lightRadius = 5;

  /// Width of each side that the lights take. Content stays between them.
  static const double sideReserve = 56;
}

/// The slab under the wheel. The wheel overlaps its top by [WheelGeometry.plinthOverlap]. It is the accent over the
/// raised surface, with a soft highlight on its top edge, a well the wheel sits in, an inner panel and three lights on
/// each side that match the bulbs.
class SpinPlinth extends StatelessWidget {
  const SpinPlinth({
    super.key,
    required this.geometry,
    required this.width,
    required this.palette,
    required this.bulbs,
    required this.child,
  });

  final WheelGeometry geometry;
  final double width;
  final WheelPalette palette;
  final ValueListenable<BulbFrame> bulbs;

  /// The content of the inner panel: the SPIN button or the result.
  final Widget child;

  double get height => geometry.plinthOverlap + PlinthMetrics.visibleHeight;

  @override
  Widget build(BuildContext context) {
    final double top = geometry.plinthOverlap + PlinthMetrics.panelGap;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _PlinthPainter(geometry: geometry, palette: palette, bulbs: bulbs),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            PlinthMetrics.sideReserve,
            top,
            PlinthMetrics.sideReserve,
            PlinthMetrics.panelGap + 4,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PlinthPainter extends CustomPainter {
  _PlinthPainter({required this.geometry, required this.palette, required this.bulbs}) : super(repaint: bulbs);

  final WheelGeometry geometry;
  final WheelPalette palette;
  final ValueListenable<BulbFrame> bulbs;

  @override
  void paint(Canvas canvas, Size size) {
    final ColorScheme cs = palette.colorScheme;
    final RRect slab = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(PrismRadius.xl));
    canvas.drawRRect(
      slab.shift(const Offset(0, 10)),
      Paint()
        ..color = cs.scrim.withValues(alpha: palette.dark ? 0.55 : 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawRRect(
      slab,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.plinthTop, palette.plinthBottom],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(slab);
    final Offset wheelCentre = Offset(size.width / 2, geometry.plinthOverlap - geometry.radius);
    final double well = geometry.radius + geometry.diameter * 0.022;
    canvas.drawCircle(
      wheelCentre,
      well,
      Paint()
        ..color = palette.ink.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, geometry.diameter * 0.012),
    );
    canvas.drawCircle(
      wheelCentre,
      well,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, palette.shine.withValues(alpha: 0.4)],
        ).createShader(Rect.fromCircle(center: wheelCentre, radius: well)),
    );
    canvas.restore();

    canvas.drawRRect(
      slab.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            palette.shine.withValues(alpha: 0.55),
            palette.shine.withValues(alpha: 0.08),
            palette.ink.withValues(alpha: 0.25),
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );

    final Rect panel = Rect.fromLTRB(
      PlinthMetrics.panelInset,
      geometry.plinthOverlap + PlinthMetrics.panelGap,
      size.width - PlinthMetrics.panelInset,
      size.height - PlinthMetrics.panelGap - 4,
    );
    final RRect panelShape = RRect.fromRectAndRadius(panel, const Radius.circular(PrismRadius.lg));
    canvas.drawRRect(panelShape, Paint()..color = palette.plinthPanel);
    canvas.drawRRect(
      panelShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.ink.withValues(alpha: 0.3), palette.shine.withValues(alpha: 0.26)],
        ).createShader(panel),
    );

    final BulbFrame frame = bulbs.value;
    final double midY = panel.center.dy;
    for (int k = 0; k < 3; k++) {
      final double y = midY + (k - 1) * PlinthMetrics.lightSpacing;
      final double lit = frame.intensity(k, period: 3);
      paintBulb(canvas, Offset(PlinthMetrics.lightInset, y), PlinthMetrics.lightRadius, lit, palette.gold);
      paintBulb(canvas, Offset(size.width - PlinthMetrics.lightInset, y), PlinthMetrics.lightRadius, lit, palette.gold);
    }
  }

  @override
  bool shouldRepaint(_PlinthPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette.colorScheme != palette.colorScheme ||
      oldDelegate.bulbs != bulbs;
}
