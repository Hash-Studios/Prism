import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:Prism/core/wallpaper/duo_reveal_geometry.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

class DuoRevealView extends StatelessWidget {
  const DuoRevealView({
    super.key,
    required this.unfolded,
    required this.image,
    required this.overlay,
    this.enabled = true,
  });

  final bool unfolded;
  final Widget image;
  final Widget overlay;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: unfolded ? 1 : 0, end: unfolded ? 1 : 0),
    duration: context.motion(PrismDurations.base),
    curve: PrismCurves.enter,
    child: image,
    builder: (context, value, child) => LayoutBuilder(
      builder: (context, constraints) {
        final Size canvas = enabled ? DuoRevealGeometry.canvas : constraints.biggest;
        final Rect visible = enabled
            ? Rect.lerp(DuoRevealGeometry.folded, Offset.zero & canvas, value)!
            : Offset.zero & canvas;
        final double scale = constraints.biggest.shortestSide <= 0
            ? 0
            : math.min(constraints.maxWidth / canvas.width, constraints.maxHeight / canvas.height);
        final double width = visible.width * scale;
        final double height = canvas.height * scale;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(enabled ? lerpDouble(28, 20, value)! : 0),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: canvas.width * scale,
                    maxWidth: canvas.width * scale,
                    minHeight: height,
                    maxHeight: height,
                    child: Transform.translate(offset: Offset(-visible.left * scale, 0), child: child),
                  ),
                  overlay,
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
