import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';

const String prismDefaultLightThemeId = 'kLFrost White';
const String prismDefaultDarkThemeId = 'kDMaterial Dark';
const String prismMaterialYouLightThemeId = 'kLMaterial You';
const String prismMaterialYouDarkThemeId = 'kDMaterial You';
const String prismAmoledDarkThemeId = 'kDAMOLED';
const String prismSpookyThemeId = 'kDSpooky';
const int prismSpookyAccentValue = 0xffff7a1a;
const String prismDiwaliThemeId = 'kDDiwali';
const int prismDiwaliAccentValue = 0xffffb020;
const int prismDefaultAccentValue = 0xffe57697;

/// A selectable app theme. [id] is the value stored in the settings, so it must not change.
class PrismThemeOption {
  const PrismThemeOption({
    required this.id,
    required this.theme,
    this.defaultAccentValue = prismDefaultAccentValue,
    this.shopItemId,
    this.usesAccent = true,
  });

  final String id;
  final ThemeData theme;
  final int defaultAccentValue;

  /// False when the theme brings its own accent. The user accent and its controls do not apply then.
  final bool usesAccent;

  /// The coin shop item that unlocks this theme, or null when the theme is free.
  final String? shopItemId;
}

PrismThemeOption? prismThemeById(List<PrismThemeOption> options, String id) =>
    options.where((option) => option.id == id).firstOrNull;

/// Localized display name for a theme. Theme IDs remain stable settings and shop keys.
String prismThemeDisplayName(PrismThemeOption option, AppLocalizations l10n) => switch (option.id) {
  prismDefaultLightThemeId => l10n.coreThemeFrostWhite,
  'kLCoffee' => l10n.coreThemeCoffee,
  'kLRose' => l10n.coreThemeRose,
  'kLCotton Blue' => l10n.coreThemeCottonBlue,
  prismDefaultDarkThemeId => l10n.coreThemeMaterialDark,
  prismMaterialYouLightThemeId || prismMaterialYouDarkThemeId => l10n.coreThemeMaterialYou,
  prismAmoledDarkThemeId => l10n.coreThemeAmoled,
  'kDOlive' => l10n.coreThemeOlive,
  'kDDeep Ocean' => l10n.coreThemeDeepOcean,
  'kDJungle' => l10n.coreThemeJungle,
  'kDPepper' => l10n.coreThemePepper,
  'kDSky' => l10n.coreThemeSky,
  'kDSteel' => l10n.coreThemeSteel,
  prismDiwaliThemeId => l10n.coreThemeDiwali,
  prismSpookyThemeId => l10n.coreThemeSpooky,
  _ => l10n.coreThemeCustom,
};

final List<PrismThemeOption> prismLightThemes = <PrismThemeOption>[
  PrismThemeOption(id: prismDefaultLightThemeId, theme: kLightTheme),
  PrismThemeOption(id: 'kLCoffee', theme: kLightTheme2, defaultAccentValue: 0xffc19439),
  PrismThemeOption(id: 'kLRose', theme: kLightTheme3, defaultAccentValue: 0xffa7796d, shopItemId: 'theme_rose'),
  PrismThemeOption(
    id: 'kLCotton Blue',
    theme: kLightTheme4,
    defaultAccentValue: 0xff596f95,
    shopItemId: 'theme_cotton_blue',
  ),
];

final List<PrismThemeOption> prismDarkThemes = <PrismThemeOption>[
  PrismThemeOption(id: prismDefaultDarkThemeId, theme: kDarkTheme),
  PrismThemeOption(id: prismAmoledDarkThemeId, theme: kDarkTheme2, defaultAccentValue: 0xffffffff),
  PrismThemeOption(id: prismDiwaliThemeId, theme: kDarkTheme10, defaultAccentValue: prismDiwaliAccentValue),
  PrismThemeOption(id: prismSpookyThemeId, theme: kDarkTheme9, defaultAccentValue: prismSpookyAccentValue),
  PrismThemeOption(id: 'kDOlive', theme: kDarkTheme3, defaultAccentValue: 0xff767b45, shopItemId: 'theme_olive'),
  PrismThemeOption(
    id: 'kDDeep Ocean',
    theme: kDarkTheme4,
    defaultAccentValue: 0xff427da8,
    shopItemId: 'theme_deep_ocean',
  ),
  PrismThemeOption(id: 'kDJungle', theme: kDarkTheme5, defaultAccentValue: 0xff4c7044, shopItemId: 'theme_jungle'),
  PrismThemeOption(id: 'kDPepper', theme: kDarkTheme6, defaultAccentValue: 0xff703826, shopItemId: 'theme_pepper'),
  PrismThemeOption(id: 'kDSky', theme: kDarkTheme7, defaultAccentValue: 0xff2d6079, shopItemId: 'theme_sky'),
  PrismThemeOption(id: 'kDSteel', theme: kDarkTheme8, defaultAccentValue: 0xff686e80, shopItemId: 'theme_steel'),
];

/// Every theme this device can show for [brightness]. Material You leads when the phone gives its colours.
List<PrismThemeOption> prismThemeOptions(Brightness brightness, SystemColorSchemes? system) {
  final bool dark = brightness == Brightness.dark;
  return <PrismThemeOption>[
    if (system != null)
      PrismThemeOption(
        id: dark ? prismMaterialYouDarkThemeId : prismMaterialYouLightThemeId,
        theme: prismMaterialYouTheme(system.of(brightness)),
        usesAccent: false,
      ),
    ...(dark ? prismDarkThemes : prismLightThemes),
  ];
}

/// The option [themeId] names on this device, or the default theme for [brightness] when it cannot show it.
PrismThemeOption resolvePrismThemeOption(String themeId, Brightness brightness, SystemColorSchemes? system) {
  final List<PrismThemeOption> options = prismThemeOptions(brightness, system);
  return prismThemeById(options, themeId) ??
      prismThemeById(options, brightness == Brightness.dark ? prismDefaultDarkThemeId : prismDefaultLightThemeId)!;
}
