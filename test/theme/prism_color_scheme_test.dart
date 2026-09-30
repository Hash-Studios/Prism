import 'dart:math' as math;

import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    test('theme ${option.id}: surface follows the theme and text is readable', () {
      final ThemeData theme = option.theme;
      final ColorScheme cs = theme.colorScheme;
      expect(cs.surface, theme.primaryColor, reason: 'surface is the theme background');
      expect(theme.scaffoldBackgroundColor, cs.surface);
      expect(_contrast(cs.onSurface, cs.surface), greaterThanOrEqualTo(6));
      expect(_contrast(cs.onSurfaceVariant, cs.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(cs.onSurface, cs.surfaceContainerHigh), greaterThanOrEqualTo(5.5));
      expect(_contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4));
      expect(cs.error, isNot(cs.primary), reason: 'error is a real danger colour, not the accent');
    });
  }
}
