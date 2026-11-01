import 'package:Prism/core/wallpaper/duo_reveal_spec.g.dart';
import 'package:flutter/painting.dart';

// ignore: avoid_classes_with_only_static_members
abstract final class DuoRevealGeometry {
  static const Size canvas = Size(DuoRevealSpec.canvasWidth * 1.0, DuoRevealSpec.canvasHeight * 1.0);

  static Rect get folded => Rect.fromLTWH(
    canvas.width * DuoRevealSpec.foldedLeftFraction,
    0,
    canvas.width * DuoRevealSpec.foldedWidthFraction,
    canvas.height,
  );

  static Rect sourceRect(Size source, {required bool unfolded}) {
    final FittedSizes fit = applyBoxFit(BoxFit.cover, source, canvas);
    final Rect covered = Alignment.center.inscribe(fit.source, Offset.zero & source);
    if (unfolded) return covered;
    return Rect.fromLTWH(
      covered.left + covered.width * DuoRevealSpec.foldedLeftFraction,
      covered.top,
      covered.width * DuoRevealSpec.foldedWidthFraction,
      covered.height,
    );
  }
}
