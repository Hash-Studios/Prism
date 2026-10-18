import 'dart:math' as math;

import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_color_scheme.dart';
import 'package:flutter/material.dart';

/// The gold of the bezel, the pegs, the pointer and the SPIN button: shades of [PrismColors.warning].
class WheelGold {
  factory WheelGold() {
    final HSLColor warning = HSLColor.fromColor(PrismColors.warning);
    Color shade(double hueShift, double saturation, double lightness) =>
        warning.withHue((warning.hue + hueShift) % 360).withSaturation(saturation).withLightness(lightness).toColor();
    return WheelGold._(
      highlight: shade(15, 1, 0.9),
      light: shade(10, 1, 0.75),
      base: shade(4, 1, 0.64),
      deep: shade(4, 0.86, 0.5),
      dark: shade(2, 0.8, 0.3),
      glint: shade(12, 1, 0.97),
      coin: shade(9, 1, 0.62),
      ink: shade(-2, 0.85, 0.16),
    );
  }

  const WheelGold._({
    required this.highlight,
    required this.light,
    required this.base,
    required this.deep,
    required this.dark,
    required this.glint,
    required this.coin,
    required this.ink,
  });

  final Color highlight;
  final Color light;
  final Color base;
  final Color deep;
  final Color dark;

  /// The near white of a specular dot or a lit bulb's core.
  final Color glint;

  /// The fill of the jackpot slice.
  final Color coin;

  /// Text on gold.
  final Color ink;

  /// A metallic sweep: light from the top left, shade at the bottom right.
  List<Color> get metal => <Color>[base, light, highlight, light, base, deep, deep, dark, deep, base];
}

/// Every colour of the wheel, from the active theme. Slice colours take the hue of the accent and step it by 90 degrees.
class WheelPalette {
  WheelPalette._({required this.colorScheme, required this.gold, required this.sliceHues});

  factory WheelPalette.of(ColorScheme colorScheme) {
    final HSLColor accent = HSLColor.fromColor(colorScheme.primary);
    // A grey accent (AMOLED white, Frost) has no hue to step. Fall back to the hue of the default pink accent.
    final double hue = accent.saturation < 0.12 ? 340 : accent.hue;
    return WheelPalette._(
      colorScheme: colorScheme,
      gold: WheelGold(),
      sliceHues: <double>[for (int i = 0; i < 4; i++) (hue + 90 * i) % 360],
    );
  }

  final ColorScheme colorScheme;
  final WheelGold gold;
  final List<double> sliceHues;

  bool get dark => colorScheme.brightness == Brightness.dark;

  /// The dark of the inner ring, the separators and the pegs' sockets.
  Color get ink => dark
      ? Color.lerp(colorScheme.surface, colorScheme.scrim, 0.55)!
      : Color.lerp(colorScheme.onSurface, colorScheme.scrim, 0.4)!;

  /// The light colour of the theme: the text colour on a dark theme, the page on a light one.
  Color get shine => dark ? colorScheme.onSurface : colorScheme.surface;

  /// The accent the aura and the plinth take.
  Color get accent => colorScheme.primary;

  /// The accent at a plinth's strength: its own hue, but always a vivid colour, whatever the theme's accent is.
  HSLColor get _plinthHsl {
    final HSLColor hsl = HSLColor.fromColor(accent);
    return hsl.saturation < 0.12
        ? const HSLColor.fromAHSL(1, 340, 0.5, 0.5)
        : hsl.withSaturation(math.max(hsl.saturation, 0.5));
  }

  /// The plinth: the accent over the raised surface, lighter at the top.
  Color get plinthTop => Color.alphaBlend(
    _plinthHsl.withLightness(dark ? 0.4 : 0.7).toColor().withValues(alpha: 0.92),
    colorScheme.surfaceContainerHigh,
  );

  Color get plinthBottom => Color.alphaBlend(
    _plinthHsl.withLightness(dark ? 0.27 : 0.58).toColor().withValues(alpha: 0.92),
    colorScheme.surfaceContainerHigh,
  );

  /// The inner panel of the plinth: a deeper step of the same colour.
  Color get plinthPanel => _plinthHsl.withLightness(dark ? 0.2 : 0.46).toColor().withValues(alpha: dark ? 0.7 : 0.45);

  /// Text and icons on the plinth.
  Color get plinthInk => prismOnColor(Color.lerp(plinthTop, plinthBottom, 0.5)!);

  /// One candy colour per slice. Four hues alternate, the jackpot slice is gold.
  List<Color> sliceColors(List<WheelSegment> segments) {
    final int n = segments.length;
    final int? jackpot = jackpotIndex(segments);
    return <Color>[
      for (int i = 0; i < n; i++)
        if (i == jackpot) gold.coin else _candy(sliceHues[_hueIndex(i, n)]),
    ];
  }

  /// The ink for text on [slice]. Dark and tinted on a bright slice, so it reads as part of the slice.
  Color inkOn(Color slice) {
    final Color onSlice = prismOnColor(slice);
    if (onSlice != Colors.black) return onSlice;
    final HSLColor hsl = HSLColor.fromColor(slice);
    return hsl.withSaturation(math.min(hsl.saturation, 0.7)).withLightness(0.13).toColor();
  }

  Color _candy(double hue) {
    final double lightness = dark ? 0.66 : 0.62;
    return HSLColor.fromAHSL(1, hue, dark ? 0.86 : 0.8, lightness).toColor();
  }

  /// Four hues in a row. A wheel of 5, 9 or 13 slices would end on the hue it starts with, so the last slice skips one.
  static int _hueIndex(int i, int n) {
    final int hue = i % 4;
    return i == n - 1 && n > 1 && hue == 0 ? 2 : hue;
  }
}

/// The slice that pays the most coins, or null when no slice pays coins.
int? jackpotIndex(List<WheelSegment> segments) {
  int? best;
  int bestCoins = 0;
  for (final (int i, WheelSegment s) in segments.indexed) {
    final WheelPrize prize = s.prize;
    if (prize is CoinsPrize && prize.coins > bestCoins) {
      best = i;
      bestCoins = prize.coins;
    }
  }
  return best;
}
