import 'package:Prism/theme/contrast.dart';
import 'package:flutter/material.dart';

/// Lowest contrast an accent needs against its theme's page background to stay visible (WCAG non-text 3:1).
const double minAccentContrast = 3;

/// Parses `#RRGGBB` or `RRGGBB` (any case, surrounding spaces ignored) into an opaque colour. Anything else is null.
Color? parseAccentHex(String input) {
  var hex = input.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// Whether [accent] stays visible on [surface].
bool accentReadsOn(Color accent, Color surface) => contrastRatio(accent, surface) >= minAccentContrast;
