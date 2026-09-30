import 'dart:math' as math;

import 'package:flutter/material.dart';

Color _mix(Color over, double alpha, Color base) => Color.alphaBlend(over.withValues(alpha: alpha), base);

const Color _ink = Color(0xFF141418);

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Dark ink or white, whichever has more contrast on [background].
Color prismOnColor(Color background) =>
    _contrast(_ink, background) >= _contrast(Colors.white, background) ? _ink : Colors.white;

/// [foreground] mixed into [background], starting at [start] and raised until it reaches 4.5:1 (or full strength).
Color _readableMix(Color foreground, Color background, double start) {
  for (double a = start; a < 1; a += 0.04) {
    final Color c = _mix(foreground, a, background);
    if (_contrast(c, background) >= 4.5) return c;
  }
  return foreground;
}

/// One colour scheme for every Prism theme. Built from the theme's page [background], its text [foreground] and
/// the user [accent], so `surface`, the `surfaceContainer` steps and `onSurface` follow the active theme variant.
ColorScheme prismColorScheme({
  required Brightness brightness,
  required Color background,
  required Color foreground,
  required Color accent,
}) {
  final bool dark = brightness == Brightness.dark;
  final ColorScheme base = dark ? const ColorScheme.dark() : const ColorScheme.light();
  final Color onAccent = prismOnColor(accent);
  final Color danger = dark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828);
  return base.copyWith(
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: _mix(accent, dark ? 0.22 : 0.16, background),
    onPrimaryContainer: foreground,
    // Legacy code reads `secondary` as the text colour. Keep it equal to the foreground.
    secondary: foreground,
    onSecondary: background,
    secondaryContainer: _mix(foreground, 0.1, background),
    onSecondaryContainer: foreground,
    tertiary: accent,
    onTertiary: onAccent,
    error: danger,
    onError: prismOnColor(danger),
    errorContainer: _mix(danger, 0.18, background),
    onErrorContainer: foreground,
    surface: background,
    onSurface: foreground,
    onSurfaceVariant: _readableMix(foreground, background, 0.66),
    surfaceDim: background,
    surfaceBright: _mix(foreground, 0.12, background),
    surfaceContainerLowest: background,
    surfaceContainerLow: _mix(foreground, 0.035, background),
    surfaceContainer: _mix(foreground, 0.055, background),
    surfaceContainerHigh: _mix(foreground, 0.08, background),
    surfaceContainerHighest: _mix(foreground, 0.12, background),
    outline: _mix(foreground, 0.28, background),
    outlineVariant: _mix(foreground, 0.1, background),
    inverseSurface: foreground,
    onInverseSurface: background,
    inversePrimary: accent,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );
}
