import 'package:flutter/material.dart';

Color darken2(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);

  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

  return hslDark.toColor();
}

Color lighten2(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);

  final hsl = HSLColor.fromColor(color);
  final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

  return hslLight.toColor();
}

Color invert2(Color color) {
  final hsl = HSLColor.fromColor(color);
  final hslInvert = hsl.withLightness(1 - hsl.lightness);

  return hslInvert.toColor();
}

extension DarkLight on Color {
  Color get darken5 => darken2(this, .05);
  Color get lighten5 => lighten2(this, .05);
  Color get darken10 => darken2(this);
  Color get lighten10 => lighten2(this);
  Color get darken20 => darken2(this, .2);
  Color get lighten20 => lighten2(this, .2);
  Color get darken30 => darken2(this, .3);
  Color get lighten30 => lighten2(this, .3);
  Color get darken50 => darken2(this, .5);
  Color get lighten50 => lighten2(this, .5);
  Color get darken70 => darken2(this, .7);
  Color get lighten70 => lighten2(this, .7);
  Color get darken90 => darken2(this, .9);
  Color get lighten90 => lighten2(this, .9);
  Color get invert => invert2(this);
}
