import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the selected tab accent reads on the page in every theme, seasonal and Material You included', () {
    final List<(String, ThemeData)> themes = <(String, ThemeData)>[
      for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes])
        (option.id, withPrismAccent(option.theme, option.defaultAccentValue)),
      for (final Brightness brightness in Brightness.values)
        (
          'materialYou-${brightness.name}',
          prismMaterialYouTheme(ColorScheme.fromSeed(seedColor: const Color(0xFFE8C547), brightness: brightness)),
        ),
    ];
    expect(themes.map((entry) => entry.$1), containsAll(<String>[prismSpookyThemeId, prismDiwaliThemeId]));
    for (final (String id, ThemeData theme) in themes) {
      final double ratio = contrastRatio(prismReadableAccent(theme), theme.colorScheme.surface);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$id accent contrast $ratio');
    }
  });
}
