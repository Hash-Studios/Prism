import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

ThemeData _withAccent(ThemeData baseTheme, int accentColorValue) {
  final Color accentColor = Color(accentColorValue);
  return baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(primary: accentColor, error: accentColor),
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
    return _withAccent(
      (prismThemeById(prismLightThemes, light.themeId) ?? prismLightThemes.first).theme,
      light.accentColorValue,
    );
  }

  ThemeData prismDarkTheme({bool listen = true}) {
    final dark = _themeState(listen).dark;
    return _withAccent(
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
