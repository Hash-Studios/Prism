import 'dart:io';

import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the accent picker colours from the theme page source, so the test follows the real list.
List<Color> _pickerColors() {
  final String source = File('lib/features/theme_mode/views/pages/theme_view_page.dart').readAsStringSync();
  final int start = source.indexOf('List<Color> _accentColors');
  if (start < 0) throw StateError('theme_view_page.dart no longer declares _accentColors');
  final String block = source.substring(start, source.indexOf('];', start));
  return RegExp(
    r'Color\(0x([0-9a-fA-F]{8})\)',
  ).allMatches(block).map((match) => Color(int.parse(match.group(1)!, radix: 16))).toList();
}

void main() {
  final List<PrismThemeOption> themes = <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes];
  final List<Color> picks = _pickerColors();

  test('the picker offers 22 colours and there are 12 themes', () {
    expect(picks, hasLength(22));
    expect(themes, hasLength(12));
  });

  for (final PrismThemeOption option in themes) {
    test('${option.label}: every picker accent keeps readable text and stays visible on the theme', () {
      for (final Color pick in picks) {
        final ColorScheme scheme = withPrismAccent(option.theme, pick.toARGB32()).colorScheme;
        final ThemeData theme = withPrismAccent(option.theme, pick.toARGB32());
        expect(
          contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: 'onPrimary on $pick in ${option.label}',
        );
        expect(
          contrastRatio(scheme.onError, scheme.error),
          greaterThanOrEqualTo(4.5),
          reason: 'onError on $pick in ${option.label}',
        );
        expect(
          contrastRatio(scheme.primary, theme.primaryColor),
          greaterThanOrEqualTo(1.5),
          reason: '$pick against the ${option.label} background',
        );
      }
    });

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
