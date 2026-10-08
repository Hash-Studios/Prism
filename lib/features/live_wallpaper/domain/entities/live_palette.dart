import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show HSLColor;

class LivePalette {
  const LivePalette({required this.colors, required this.background});

  /// Builds four related colours and a background from the user accent.
  /// Dark themes get a deep background and light themes a soft one.
  factory LivePalette.fromAccent(Color accent, {required bool dark}) {
    final HSLColor base = HSLColor.fromColor(accent);
    final double saturation = base.saturation.clamp(0.45, 0.9);
    final double lightness = dark ? base.lightness.clamp(0.45, 0.65) : base.lightness.clamp(0.4, 0.6);
    Color shifted(double hueShift, {double lightnessShift = 0, double saturationScale = 1}) {
      return HSLColor.fromAHSL(
        1,
        (base.hue + hueShift) % 360,
        (saturation * saturationScale).clamp(0.0, 1.0),
        (lightness + lightnessShift).clamp(0.0, 1.0),
      ).toColor();
    }

    return LivePalette(
      colors: <Color>[
        shifted(0),
        shifted(38, lightnessShift: 0.06),
        shifted(-42, lightnessShift: -0.04),
        shifted(180, lightnessShift: -0.08, saturationScale: 0.7),
      ],
      background: HSLColor.fromAHSL(1, base.hue, dark ? 0.35 : 0.3, dark ? 0.06 : 0.93).toColor(),
    );
  }

  /// The seed and three related seeds, for the colour picker. Hues match the shifts in [LivePalette.fromAccent].
  static List<Color> seedVariants(Color seed) {
    final HSLColor base = HSLColor.fromColor(seed);
    return <Color>[
      seed,
      ...<double>[38, -42, 180].map((shift) => base.withHue((base.hue + shift) % 360).toColor()),
    ];
  }

  final List<Color> colors;
  final Color background;
}
