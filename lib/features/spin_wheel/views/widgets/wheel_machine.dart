import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_bezel.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_face.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_pointer.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The wheel with everything on it, in layers. From the back: the bezel with its bulbs (static), the face with its
/// labels (it turns, in its own layer), the hub (static) and the pointer. The pointer's flapper reaches above the
/// wheel, so the stack does not clip.
class WheelMachine extends StatelessWidget {
  const WheelMachine({
    super.key,
    required this.segments,
    required this.geometry,
    required this.theta,
    required this.flapper,
    required this.bulbs,
    this.winner,
    this.dim = 0,
    this.showLabels = true,
  });

  final List<WheelSegment> segments;
  final WheelGeometry geometry;

  /// The wheel angle in radians, clockwise.
  final ValueListenable<double> theta;

  /// The swing of the pointer's flapper in radians.
  final ValueListenable<double> flapper;
  final ValueListenable<BulbFrame> bulbs;

  /// The slice to keep bright once the wheel has landed, and how far the others dim.
  final int? winner;
  final double dim;

  /// False for the small wheel on the Rewards card.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final WheelPalette palette = WheelPalette.of(Theme.of(context).colorScheme);
    final Size size = Size.square(geometry.diameter);
    return Semantics(
      label: context.l10n.economyPrizeWheel,
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: WheelBezelPainter(geometry: geometry, palette: palette, frame: bulbs),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: theta,
              child: RepaintBoundary(
                child: WheelFace(
                  segments: segments,
                  palette: palette,
                  geometry: geometry,
                  winner: winner,
                  dim: dim,
                  showLabels: showLabels,
                ),
              ),
              builder: (BuildContext context, double angle, Widget? face) =>
                  Transform.rotate(angle: angle, child: face),
            ),
            Center(
              child: WheelHub(geometry: geometry, palette: palette),
            ),
            CustomPaint(
              size: size,
              painter: WheelPointerPainter(geometry: geometry, palette: palette, angle: flapper),
            ),
          ],
        ),
      ),
    );
  }
}
