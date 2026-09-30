import 'package:Prism/features/theme_dark/theme_dark.dart';
import 'package:Prism/features/theme_light/theme_light.dart';
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
  ThemeLightBloc _themeLightBloc(bool listen) => listen ? watch<ThemeLightBloc>() : read<ThemeLightBloc>();

  ThemeDarkBloc _themeDarkBloc(bool listen) => listen ? watch<ThemeDarkBloc>() : read<ThemeDarkBloc>();

  ThemeModeBloc _themeModeBloc(bool listen) => listen ? watch<ThemeModeBloc>() : read<ThemeModeBloc>();

  ThemeData prismLightTheme({bool listen = true}) {
    final state = _themeLightBloc(listen).state;
    return _withAccent(
      (prismThemeById(prismLightThemes, state.theme.themeId) ?? prismLightThemes.first).theme,
      state.theme.accentColorValue,
    );
  }

  ThemeData prismDarkTheme({bool listen = true}) {
    final state = _themeDarkBloc(listen).state;
    return _withAccent(
      (prismThemeById(prismDarkThemes, state.theme.themeId) ?? prismDarkThemes.first).theme,
      state.theme.accentColorValue,
    );
  }

  String prismLightThemeId({bool listen = true}) => _themeLightBloc(listen).state.theme.themeId;

  String prismDarkThemeId({bool listen = true}) => _themeDarkBloc(listen).state.theme.themeId;

  int prismLightAccentValue({bool listen = true}) => _themeLightBloc(listen).state.theme.accentColorValue;

  int prismDarkAccentValue({bool listen = true}) => _themeDarkBloc(listen).state.theme.accentColorValue;

  ThemeMode prismThemeMode({bool listen = true}) => _themeModeBloc(listen).state.mode.mode;

  String prismModeAbs({bool listen = true}) => _modeAbsoluteLabel(_themeModeBloc(listen).state.mode.mode);

  bool prismIsAmoledDark({bool listen = true}) => prismDarkThemeId(listen: listen) == prismAmoledDarkThemeId;

  void setPrismThemeMode(ThemeMode mode) {
    read<ThemeModeBloc>().add(ThemeModeEvent.modeChanged(mode: mode));
  }

  void setPrismLightTheme(String themeId) {
    read<ThemeLightBloc>().add(ThemeLightEvent.themeChanged(themeId: themeId));
  }

  void setPrismDarkTheme(String themeId) {
    read<ThemeDarkBloc>().add(ThemeDarkEvent.themeChanged(themeId: themeId));
  }

  void setPrismLightAccent(Color? accentColor) {
    if (accentColor == null) {
      return;
    }
    read<ThemeLightBloc>().add(ThemeLightEvent.accentChanged(accentColorValue: accentColor.toARGB32()));
  }

  void setPrismDarkAccent(Color? accentColor) {
    if (accentColor == null) {
      return;
    }
    read<ThemeDarkBloc>().add(ThemeDarkEvent.accentChanged(accentColorValue: accentColor.toARGB32()));
  }
}
