import 'package:flutter/material.dart';

class ThemeSelection {
  const ThemeSelection({required this.themeId, required this.accentColorValue});

  final String themeId;
  final int accentColorValue;
}

class ThemePreferences {
  const ThemePreferences({required this.light, required this.dark, required this.mode});

  final ThemeSelection light;
  final ThemeSelection dark;
  final ThemeMode mode;
}
