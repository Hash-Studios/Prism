import 'dart:math' as math;

import 'package:Prism/features/theme_mode/views/pages/theme_view_widgets.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_color_scheme.dart';
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
      expect(_contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5));
      expect(_contrast(cs.onError, cs.error), greaterThanOrEqualTo(4.5));
      expect(cs.error, isNot(cs.primary), reason: 'error is a real danger colour, not the accent');
    });

    testWidgets('theme ${option.id}: all text roles stay readable on every surface container', (tester) async {
      final Map<String, Map<Color, double>> contrasts = <String, Map<Color, double>>{};
      await tester.pumpWidget(
        MaterialApp(
          theme: option.theme,
          home: Builder(
            builder: (context) {
              final ColorScheme cs = Theme.of(context).colorScheme;
              final List<Color> surfaces = <Color>[
                cs.surface,
                cs.surfaceContainerLowest,
                cs.surfaceContainerLow,
                cs.surfaceContainer,
                cs.surfaceContainerHigh,
                cs.surfaceContainerHighest,
              ];
              final Map<String, Color> roles = <String, Color>{
                'onSurfaceVariant': cs.onSurfaceVariant,
                'error': cs.error,
                'body': PrismTextStyles.body(context).color!,
                'caption': PrismTextStyles.caption(context).color!,
                'eyebrow': PrismTextStyles.eyebrow(context).color!,
              };
              for (final MapEntry<String, Color> role in roles.entries) {
                contrasts[role.key] = <Color, double>{
                  for (final Color surface in surfaces)
                    surface: _contrast(Color.alphaBlend(role.value, surface), surface),
                };
              }
              return const SizedBox();
            },
          ),
        ),
      );

      for (final MapEntry<String, Map<Color, double>> role in contrasts.entries) {
        for (final double ratio in role.value.values) {
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '${option.id} ${role.key} on a container surface');
        }
      }
    });
  }

  test('all shipped and reported accent colors have readable on-accent text', () {
    final List<Color> accents = <Color>{
      for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes])
        option.theme.colorScheme.primary,
      for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes])
        Color(option.defaultAccentValue),
      ...prismAccentSwatches,
    }.toList();
    for (final Color accent in accents) {
      final Color onAccent = prismOnColor(accent);
      expect(_contrast(onAccent, accent), greaterThanOrEqualTo(4.5), reason: 'on $accent');
    }
  });
}
