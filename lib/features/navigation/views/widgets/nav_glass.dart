import 'dart:ui' as ui;

import 'package:Prism/theme/contrast.dart';
import 'package:flutter/material.dart';

/// The frosted surface of the floating navigation. The page behind it blurs through a translucent pill colour, with a
/// hairline edge and a soft shadow, so a wallpaper shows through tinted. [circle] draws a disc, else a pill.
///
/// It blurs with [BackdropFilter.grouped], so the controls under one [BackdropGroup] share a single backdrop read.
class NavGlass extends StatelessWidget {
  const NavGlass({super.key, required this.child, this.circle = false});

  static const double blurSigma = 24;

  /// The usual tint. [tintOf] raises it for a theme whose ink needs more.
  static const double tintAlpha = 0.72;

  /// The tint for [theme]: [tintAlpha], or more where the tab ink (`secondary`) would drop under 4.5:1, or its 60%
  /// inactive ink under 3:1, over a black or a white wall behind the glass.
  static double tintOf(ThemeData theme) {
    final Color ink = theme.colorScheme.secondary;
    bool readable(double alpha) => const <Color>[Colors.black, Colors.white].every((Color wall) {
      final Color glass = Color.alphaBlend(theme.primaryColor.withValues(alpha: alpha), wall);
      return contrastRatio(ink, glass) >= 4.5 &&
          contrastRatio(Color.alphaBlend(ink.withValues(alpha: 0.6), glass), glass) >= 3;
    });
    double alpha = tintAlpha;
    while (alpha < 1 && !readable(alpha)) {
      alpha += 0.02;
    }
    return alpha.clamp(0, 1);
  }

  final Widget child;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderSide hairline = BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08), width: 0.5);
    final ShapeBorder shape = circle ? CircleBorder(side: hairline) : StadiumBorder(side: hairline);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter.grouped(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.primaryColor.withValues(alpha: tintOf(theme)),
              shape: shape,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
