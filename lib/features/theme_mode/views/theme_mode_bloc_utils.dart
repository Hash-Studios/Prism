import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Applies the user accent to [baseTheme]. An accent that nearly matches the theme background (black on AMOLED)
/// is replaced by the theme's own accent. The text colours on the accent are picked for contrast.
ThemeData withPrismAccent(ThemeData baseTheme, int accentColorValue) {
  Color accentColor = Color(accentColorValue);
  if (contrastRatio(accentColor, baseTheme.primaryColor) < 1.5) {
    accentColor = baseTheme.colorScheme.primary;
  }
  final Color onAccent = onColor(accentColor);
  return baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(
      primary: accentColor,
      error: accentColor,
      onPrimary: onAccent,
      onError: onAccent,
    ),
  );
}

String _modeAbsoluteLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
  ThemeMode.system => 'System (Light/Dark)',
};

extension PrismThemeContextX on BuildContext {
  ThemeState _themeState(bool listen) => (listen ? watch<ThemeBloc>() : read<ThemeBloc>()).state;

  ThemeData prismLightTheme({bool listen = true}) {
    final light = _themeState(listen).light;
    return withPrismAccent(
      (prismThemeById(prismLightThemes, light.themeId) ?? prismLightThemes.first).theme,
      light.accentColorValue,
    );
  }

  ThemeData prismDarkTheme({bool listen = true}) {
    final dark = _themeState(listen).dark;
    return withPrismAccent(
      (prismThemeById(prismDarkThemes, dark.themeId) ?? prismDarkThemes.first).theme,
      dark.accentColorValue,
    );
  }

  String prismLightThemeId({bool listen = true}) => _themeState(listen).light.themeId;

  String prismDarkThemeId({bool listen = true}) => _themeState(listen).dark.themeId;

  int prismLightAccentValue({bool listen = true}) => _themeState(listen).light.accentColorValue;

  int prismDarkAccentValue({bool listen = true}) => _themeState(listen).dark.accentColorValue;

  ThemeMode prismThemeMode({bool listen = true}) => _themeState(listen).mode;

  String prismModeAbs({bool listen = true}) => _modeAbsoluteLabel(_themeState(listen).mode);

  bool prismIsAmoledDark({bool listen = true}) => prismDarkThemeId(listen: listen) == prismAmoledDarkThemeId;

  void setPrismThemeMode(ThemeMode mode) {
    read<ThemeBloc>().add(ThemeEvent.modeChanged(mode: mode));
  }

  void setPrismLightTheme(String themeId) {
    read<ThemeBloc>().add(ThemeEvent.lightThemeChanged(themeId: themeId));
  }

  void setPrismDarkTheme(String themeId) {
    read<ThemeBloc>().add(ThemeEvent.darkThemeChanged(themeId: themeId));
  }

  void setPrismLightAccent(Color? accentColor) {
    if (accentColor == null) {
      return;
    }
    read<ThemeBloc>().add(ThemeEvent.lightAccentChanged(accentColorValue: accentColor.toARGB32()));
  }

  void setPrismDarkAccent(Color? accentColor) {
    if (accentColor == null) {
      return;
    }
    read<ThemeBloc>().add(ThemeEvent.darkAccentChanged(accentColorValue: accentColor.toARGB32()));
  }
}
