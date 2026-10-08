import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter/material.dart';

/// A phone-shaped frame. The art fills it and the chrome stays quiet.
class LiveStylePreview extends StatelessWidget {
  const LiveStylePreview({super.key, required this.child, required this.semanticLabel});

  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height * 0.4;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Center(
        child: SizedBox(
          height: height,
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
          ),
        ),
      ),
    );
  }
}

/// A still approximation of each gradient style, drawn with the same palette as the shader.
Gradient liveGradientPreview(GradientStyle style, LivePalette palette) {
  final List<Color> c = palette.colors;
  switch (style) {
    case GradientStyle.aurora:
      return LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          palette.background,
          c[0].withValues(alpha: 0.85),
          c[1].withValues(alpha: 0.7),
          palette.background,
        ],
        stops: const <double>[0.0, 0.45, 0.7, 1.0],
      );
    case GradientStyle.mesh:
      return RadialGradient(
        center: const Alignment(-0.5, -0.6),
        radius: 1.3,
        colors: <Color>[c[0], c[2], c[3], palette.background],
        stops: const <double>[0.0, 0.4, 0.7, 1.0],
      );
    case GradientStyle.waves:
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[palette.background, c[3], c[2], c[1], c[0]],
      );
    case GradientStyle.plasma:
      return SweepGradient(colors: <Color>[c[0], c[1], c[2], c[3], c[0]]);
    case GradientStyle.starfield:
      return RadialGradient(
        center: Alignment.topCenter,
        radius: 1.2,
        colors: <Color>[c[0].withValues(alpha: 0.18), const Color(0xFF000000)],
      );
  }
}
