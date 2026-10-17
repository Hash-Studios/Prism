import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';

const String prismDefaultLightThemeId = 'kLFrost White';
const String prismDefaultDarkThemeId = 'kDMaterial Dark';
const String prismAmoledDarkThemeId = 'kDAMOLED';
const int prismDefaultAccentValue = 0xffe57697;

/// A selectable app theme. [id] is the value stored in the settings, so it must not change.
class PrismThemeOption {
  const PrismThemeOption({
    required this.id,
    required this.label,
    required this.theme,
    this.defaultAccentValue = prismDefaultAccentValue,
    this.shopItemId,
  });

  final String id;
  final String label;
  final ThemeData theme;
  final int defaultAccentValue;

  /// The coin shop item that unlocks this theme, or null when the theme is free.
  final String? shopItemId;
}

PrismThemeOption? prismThemeById(List<PrismThemeOption> options, String id) =>
    options.where((option) => option.id == id).firstOrNull;

final List<PrismThemeOption> prismLightThemes = <PrismThemeOption>[
  PrismThemeOption(id: prismDefaultLightThemeId, label: 'Frost White', theme: kLightTheme),
  PrismThemeOption(id: 'kLCoffee', label: 'Coffee', theme: kLightTheme2, defaultAccentValue: 0xffc19439),
  PrismThemeOption(
    id: 'kLRose',
    label: 'Rose',
    theme: kLightTheme3,
    defaultAccentValue: 0xffa7796d,
    shopItemId: 'theme_rose',
  ),
  PrismThemeOption(
    id: 'kLCotton Blue',
    label: 'Cotton Blue',
    theme: kLightTheme4,
    defaultAccentValue: 0xff596f95,
    shopItemId: 'theme_cotton_blue',
  ),
];

final List<PrismThemeOption> prismDarkThemes = <PrismThemeOption>[
  PrismThemeOption(id: prismDefaultDarkThemeId, label: 'Material Dark', theme: kDarkTheme),
  PrismThemeOption(id: prismAmoledDarkThemeId, label: 'AMOLED', theme: kDarkTheme2, defaultAccentValue: 0xffffffff),
  PrismThemeOption(
    id: 'kDOlive',
    label: 'Olive',
    theme: kDarkTheme3,
    defaultAccentValue: 0xff767b45,
    shopItemId: 'theme_olive',
  ),
  PrismThemeOption(
    id: 'kDDeep Ocean',
    label: 'Deep Ocean',
    theme: kDarkTheme4,
    defaultAccentValue: 0xff427da8,
    shopItemId: 'theme_deep_ocean',
  ),
  PrismThemeOption(
    id: 'kDJungle',
    label: 'Jungle',
    theme: kDarkTheme5,
    defaultAccentValue: 0xff4c7044,
    shopItemId: 'theme_jungle',
  ),
  PrismThemeOption(
    id: 'kDPepper',
    label: 'Pepper',
    theme: kDarkTheme6,
    defaultAccentValue: 0xff703826,
    shopItemId: 'theme_pepper',
  ),
  PrismThemeOption(
    id: 'kDSky',
    label: 'Sky',
    theme: kDarkTheme7,
    defaultAccentValue: 0xff2d6079,
    shopItemId: 'theme_sky',
  ),
  PrismThemeOption(
    id: 'kDSteel',
    label: 'Steel',
    theme: kDarkTheme8,
    defaultAccentValue: 0xff686e80,
    shopItemId: 'theme_steel',
  ),
];
