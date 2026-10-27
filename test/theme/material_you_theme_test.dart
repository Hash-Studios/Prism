import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ColorScheme light = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));
  final ColorScheme dark = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC), brightness: Brightness.dark);
  final SystemColorSchemes schemes = SystemColorSchemes(light: light, dark: dark);

  group('prismMaterialYouTheme', () {
    test('light theme uses the light scheme', () {
      final ThemeData theme = prismMaterialYouTheme(light);

      expect(theme.colorScheme, light);
      expect(theme.scaffoldBackgroundColor, light.surface);
      expect(theme.primaryColor, light.surface);
      expect(theme.brightness, Brightness.light);
      expect(theme.canvasColor, Colors.transparent);
      expect(theme.textTheme.bodyMedium?.fontFamily, PrismFonts.proximaNova);
      expect(theme.chipTheme.shape, isA<StadiumBorder>());
      expect(theme.filledButtonTheme.style?.backgroundColor?.resolve({}), light.primary);
    });

    test('dark theme uses the dark scheme', () {
      final ThemeData theme = prismMaterialYouTheme(dark);

      expect(theme.colorScheme, dark);
      expect(theme.scaffoldBackgroundColor, dark.surface);
      expect(theme.primaryColor, dark.surface);
      expect(theme.brightness, Brightness.dark);
      expect(theme.canvasColor, Colors.transparent);
      expect(theme.textTheme.bodyMedium?.fontFamily, PrismFonts.proximaNova);
      expect(theme.chipTheme.shape, isA<StadiumBorder>());
      expect(theme.filledButtonTheme.style?.backgroundColor?.resolve({}), dark.primary);
    });
  });

  group('prismThemeOptions', () {
    test('light without system schemes has no Material You option and leads with the default', () {
      final List<String> ids = prismThemeOptions(Brightness.light, null).map((option) => option.id).toList();

      expect(ids, isNot(contains(prismMaterialYouLightThemeId)));
      expect(ids.first, prismDefaultLightThemeId);
    });

    test('light with system schemes leads with Material You and keeps the light themes in order', () {
      final List<PrismThemeOption> options = prismThemeOptions(Brightness.light, schemes);
      final PrismThemeOption first = options.first;

      expect(first.id, prismMaterialYouLightThemeId);
      expect(first.usesAccent, isFalse);
      expect(first.shopItemId, isNull);
      expect(first.theme.colorScheme, light);
      expect(options.skip(1).map((option) => option.id).toList(), prismLightThemes.map((option) => option.id).toList());
    });

    test('dark without system schemes has no Material You option and leads with the default', () {
      final List<String> ids = prismThemeOptions(Brightness.dark, null).map((option) => option.id).toList();

      expect(ids, isNot(contains(prismMaterialYouDarkThemeId)));
      expect(ids.first, prismDefaultDarkThemeId);
    });

    test('dark with system schemes leads with Material You and keeps the dark themes in order', () {
      final List<PrismThemeOption> options = prismThemeOptions(Brightness.dark, schemes);
      final PrismThemeOption first = options.first;

      expect(first.id, prismMaterialYouDarkThemeId);
      expect(first.usesAccent, isFalse);
      expect(first.shopItemId, isNull);
      expect(first.theme.colorScheme, dark);
      expect(options.skip(1).map((option) => option.id).toList(), prismDarkThemes.map((option) => option.id).toList());
    });
  });

  group('resolvePrismThemeOption', () {
    test('Material You light id falls back to the default light theme without system schemes', () {
      expect(
        resolvePrismThemeOption(prismMaterialYouLightThemeId, Brightness.light, null).id,
        prismDefaultLightThemeId,
      );
    });

    test('Material You dark id falls back to the default dark theme without system schemes', () {
      expect(resolvePrismThemeOption(prismMaterialYouDarkThemeId, Brightness.dark, null).id, prismDefaultDarkThemeId);
    });

    test('Material You ids resolve to Material You when system schemes exist', () {
      expect(
        resolvePrismThemeOption(prismMaterialYouLightThemeId, Brightness.light, schemes).id,
        prismMaterialYouLightThemeId,
      );
      expect(
        resolvePrismThemeOption(prismMaterialYouDarkThemeId, Brightness.dark, schemes).id,
        prismMaterialYouDarkThemeId,
      );
    });

    test('an unknown id falls back to the default light theme', () {
      expect(resolvePrismThemeOption('kLNope', Brightness.light, null).id, prismDefaultLightThemeId);
    });

    test('a known id resolves to itself', () {
      expect(resolvePrismThemeOption('kLCoffee', Brightness.light, null).id, 'kLCoffee');
    });
  });

  group('prismThemeDisplayName', () {
    test('both Material You options are named Material You', () {
      final AppLocalizationsEn l10n = AppLocalizationsEn();

      expect(prismThemeDisplayName(prismThemeOptions(Brightness.light, schemes).first, l10n), 'Material You');
      expect(prismThemeDisplayName(prismThemeOptions(Brightness.dark, schemes).first, l10n), 'Material You');
    });
  });
}
