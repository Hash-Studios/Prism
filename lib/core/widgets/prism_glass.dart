import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Liquid glass surface for chrome that floats over a wallpaper.
/// iOS renders real refraction. Other platforms render the package's blurred fake, which is cheaper on the GPU.
class PrismGlass extends StatelessWidget {
  const PrismGlass({required this.borderRadius, required this.child, this.glassColor, this.thickness = 40, super.key});

  final double borderRadius;
  final Widget child;

  /// Tint of the glass. Defaults to the theme's primary colour at 20 percent.
  final Color? glassColor;

  /// Depth of the refraction on iOS. Pills of 48 px or less pass 16.
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLayer(
      settings: LiquidGlassSettings(
        thickness: thickness,
        ambientStrength: 0.2,
        blur: 4,
        glassColor: glassColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.2),
      ),
      fake: defaultTargetPlatform != TargetPlatform.iOS,
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        child: child,
      ),
    );
  }
}
