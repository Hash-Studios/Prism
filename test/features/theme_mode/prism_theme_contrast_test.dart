import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<PrismThemeOption> themes = <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes];
  for (final PrismThemeOption option in themes) {
    test('${option.label}: its own default accent is kept and readable', () {
      final ThemeData theme = withPrismAccent(option.theme, option.defaultAccentValue);

      expect(theme.colorScheme.primary, Color(option.defaultAccentValue));
      expect(contrastRatio(theme.colorScheme.onPrimary, theme.colorScheme.primary), greaterThanOrEqualTo(4.5));
    });

    testWidgets('${option.label}: caption and eyebrow text pass 4.5 on the theme background', (tester) async {
      late TextStyle caption;
      late TextStyle eyebrow;
      await tester.pumpWidget(
        MaterialApp(
          theme: option.theme,
          home: Builder(
            builder: (context) {
              caption = PrismTextStyles.caption(context);
              eyebrow = PrismTextStyles.eyebrow(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final Color background = option.theme.primaryColor;

      expect(contrastRatio(Color.alphaBlend(caption.color!, background), background), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(Color.alphaBlend(eyebrow.color!, background), background), greaterThanOrEqualTo(4.5));
    });
  }

  test('black accent on AMOLED falls back to the theme accent instead of vanishing', () {
    final ThemeData amoled = prismThemeById(prismDarkThemes, prismAmoledDarkThemeId)!.theme;
    final ColorScheme scheme = withPrismAccent(amoled, 0xff000000).colorScheme;

    expect(scheme.primary, Colors.white);
    expect(scheme.onPrimary, Colors.black);
  });

  test('a stock dark accent that sits below 3:1 is not replaced', () {
    final PrismThemeOption pepper = prismThemeById(prismDarkThemes, 'kDPepper')!;
    final ThemeData theme = withPrismAccent(pepper.theme, pepper.defaultAccentValue);

    expect(contrastRatio(theme.colorScheme.primary, theme.primaryColor), lessThan(3));
    expect(theme.colorScheme.primary, Color(pepper.defaultAccentValue));
  });
}
