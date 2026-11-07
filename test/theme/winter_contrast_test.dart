import 'package:Prism/features/theme_mode/views/widgets/winter_decor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Color> _surfaces(ColorScheme colors) => <String, Color>{
  'surface': colors.surface,
  'lowest': colors.surfaceContainerLowest,
  'low': colors.surfaceContainerLow,
  'container': colors.surfaceContainer,
  'high': colors.surfaceContainerHigh,
  'highest': colors.surfaceContainerHighest,
};

void _expectReadable(ColorScheme colors) {
  final Map<String, Color> roles = <String, Color>{
    'onSurface': colors.onSurface,
    'onSurfaceVariant': colors.onSurfaceVariant,
    'primary': colors.primary,
    'tertiary': colors.tertiary,
    'error': colors.error,
  };
  for (final MapEntry<String, Color> surface in _surfaces(colors).entries) {
    for (final MapEntry<String, Color> role in roles.entries) {
      expect(
        contrastRatio(Color.alphaBlend(role.value, surface.value), surface.value),
        greaterThanOrEqualTo(4.5),
        reason: '${role.key} on ${surface.key}',
      );
    }
  }
  expect(contrastRatio(colors.onPrimary, colors.primary), greaterThanOrEqualTo(4.5));
  expect(contrastRatio(colors.onTertiary, colors.tertiary), greaterThanOrEqualTo(4.5));
  expect(contrastRatio(colors.onPrimaryContainer, colors.primaryContainer), greaterThanOrEqualTo(4.5));
  expect(contrastRatio(colors.onSecondaryContainer, colors.secondaryContainer), greaterThanOrEqualTo(4.5));
  expect(contrastRatio(colors.onErrorContainer, colors.errorContainer), greaterThanOrEqualTo(4.5));
}

void main() {
  final List<PrismThemeOption> winterThemes = <PrismThemeOption>[
    prismThemeById(prismLightThemes, prismWinterLightThemeId)!,
    prismThemeById(prismDarkThemes, prismWinterDarkThemeId)!,
  ];
  for (final PrismThemeOption option in winterThemes) {
    test('${option.id} default text and accent pass AA on every surface container', () {
      _expectReadable(option.theme.colorScheme);
    });

    testWidgets('${option.id} New Year pill text passes AA on its actual fill', (tester) async {
      final ThemeData theme = option.theme;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: WinterNewYearGreeting()),
        ),
      );
      final Finder label = find.text('Happy New Year');
      final RichText text = tester.widget<RichText>(find.descendant(of: label, matching: find.byType(RichText)));
      final Container pill = tester.widget<Container>(find.ancestor(of: label, matching: find.byType(Container)).first);
      final Color fill = (pill.decoration! as BoxDecoration).color!;
      expect(fill, theme.colorScheme.surfaceContainerHighest);
      expect(contrastRatio(Color.alphaBlend(text.text.style!.color!, fill), fill), greaterThanOrEqualTo(4.5));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
