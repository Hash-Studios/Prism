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
  });

  final String id;
  final String label;
  final ThemeData theme;
  final int defaultAccentValue;
}

PrismThemeOption? prismThemeById(List<PrismThemeOption> options, String id) =>
    options.where((option) => option.id == id).firstOrNull;

final List<PrismThemeOption> prismLightThemes = <PrismThemeOption>[
  PrismThemeOption(id: prismDefaultLightThemeId, label: 'Frost White', theme: kLightTheme),
  PrismThemeOption(id: 'kLCoffee', label: 'Coffee', theme: kLightTheme2, defaultAccentValue: 0xffc19439),
  PrismThemeOption(id: 'kLRose', label: 'Rose', theme: kLightTheme3, defaultAccentValue: 0xffa7796d),
  PrismThemeOption(id: 'kLCotton Blue', label: 'Cotton Blue', theme: kLightTheme4, defaultAccentValue: 0xff596f95),
];

final List<PrismThemeOption> prismDarkThemes = <PrismThemeOption>[
  PrismThemeOption(id: prismDefaultDarkThemeId, label: 'Material Dark', theme: kDarkTheme),
  PrismThemeOption(id: prismAmoledDarkThemeId, label: 'AMOLED', theme: kDarkTheme2, defaultAccentValue: 0xff000000),
  PrismThemeOption(id: 'kDOlive', label: 'Olive', theme: kDarkTheme3, defaultAccentValue: 0xff767b45),
  PrismThemeOption(id: 'kDDeep Ocean', label: 'Deep Ocean', theme: kDarkTheme4, defaultAccentValue: 0xff427da8),
  PrismThemeOption(id: 'kDJungle', label: 'Jungle', theme: kDarkTheme5, defaultAccentValue: 0xff4c7044),
  PrismThemeOption(id: 'kDPepper', label: 'Pepper', theme: kDarkTheme6, defaultAccentValue: 0xff703826),
  PrismThemeOption(id: 'kDSky', label: 'Sky', theme: kDarkTheme7, defaultAccentValue: 0xff2d6079),
  PrismThemeOption(id: 'kDSteel', label: 'Steel', theme: kDarkTheme8, defaultAccentValue: 0xff686e80),
];
