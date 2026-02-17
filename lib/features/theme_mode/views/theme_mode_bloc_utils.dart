import 'package:Prism/features/theme_dark/theme_dark.dart';
import 'package:Prism/features/theme_light/theme_light.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final Map<String, ThemeData> prismLightThemes = <String, ThemeData>{
  'kLFrost White': kLightTheme,
  'kLCoffee': kLightTheme2,
  'kLRose': kLightTheme3,
  'kLCotton Blue': kLightTheme4,
};

final Map<String, ThemeData> prismDarkThemes = <String, ThemeData>{
  'kDMaterial Dark': kDarkTheme,
  'kDAMOLED': kDarkTheme2,
  'kDOlive': kDarkTheme3,
  'kDDeep Ocean': kDarkTheme4,
  'kDJungle': kDarkTheme5,
  'kDPepper': kDarkTheme6,
  'kDSky': kDarkTheme7,
  'kDSteel': kDarkTheme8,
};

const String prismAmoledDarkThemeId = 'kDAMOLED';

final class PrismThemeMapper {
  const PrismThemeMapper();

  String identity() => 'PrismThemeMapper';

  static const String _fallbackLightThemeId = 'kLFrost White';
  static const String _fallbackDarkThemeId = 'kDMaterial Dark';

  static ThemeData resolveLightTheme({
    required String themeId,
    required int accentColorValue,
  }) {
    final ThemeData baseTheme = prismLightThemes[themeId] ?? prismLightThemes[_fallbackLightThemeId]!;
    final Color accentColor = Color(accentColorValue);
    return baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: accentColor,
        error: accentColor,
      ),
    );
  }

  static ThemeData resolveDarkTheme({
    required String themeId,
    required int accentColorValue,
  }) {
    final ThemeData baseTheme = prismDarkThemes[themeId] ?? prismDarkThemes[_fallbackDarkThemeId]!;
    final Color accentColor = Color(accentColorValue);
    return baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: accentColor,
        error: accentColor,
      ),
    );
  }

  static ThemeMode resolveMode(String mode) {
    switch (mode) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      case 'System':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String modeStyle({
    required String mode,
    required Brightness brightness,
  }) {
    if (mode == 'Light') {
      return 'Light';
    }
    if (mode == 'Dark') {
      return 'Dark';
    }
    if (mode == 'System') {
      return brightness == Brightness.light ? 'Light' : 'Dark';
    }
    return 'Dark';
  }

  static String modeAbsoluteLabel(String mode) {
    if (mode == 'Light') {
      return 'Light';
    }
    if (mode == 'Dark') {
      return 'Dark';
    }
    if (mode == 'System') {
      return 'System (Light/Dark)';
    }
    return 'Dark';
  }

  static int? lightThemeIndex(String themeId) {
    final index = prismLightThemes.keys.toList().indexOf(themeId);
    return index >= 0 ? index : null;
  }

  static int? darkThemeIndex(String themeId) {
    final index = prismDarkThemes.keys.toList().indexOf(themeId);
    return index >= 0 ? index : null;
  }
}

extension PrismThemeContextX on BuildContext {
  ThemeLightBloc _themeLightBloc(bool listen) => listen ? watch<ThemeLightBloc>() : read<ThemeLightBloc>();

  ThemeDarkBloc _themeDarkBloc(bool listen) => listen ? watch<ThemeDarkBloc>() : read<ThemeDarkBloc>();

  ThemeModeBloc _themeModeBloc(bool listen) => listen ? watch<ThemeModeBloc>() : read<ThemeModeBloc>();

  ThemeData prismLightTheme({bool listen = true}) {
    final state = _themeLightBloc(listen).state;
    return PrismThemeMapper.resolveLightTheme(
      themeId: state.theme.themeId,
      accentColorValue: state.theme.accentColorValue,
    );
  }

  ThemeData prismDarkTheme({bool listen = true}) {
    final state = _themeDarkBloc(listen).state;
    return PrismThemeMapper.resolveDarkTheme(
      themeId: state.theme.themeId,
      accentColorValue: state.theme.accentColorValue,
    );
  }

  String prismLightThemeId({bool listen = true}) => _themeLightBloc(listen).state.theme.themeId;

  String prismDarkThemeId({bool listen = true}) => _themeDarkBloc(listen).state.theme.themeId;

  int prismLightAccentValue({bool listen = true}) => _themeLightBloc(listen).state.theme.accentColorValue;

  int prismDarkAccentValue({bool listen = true}) => _themeDarkBloc(listen).state.theme.accentColorValue;

  ThemeMode prismThemeMode({bool listen = true}) =>
      PrismThemeMapper.resolveMode(_themeModeBloc(listen).state.mode.mode);

  String prismModeStyle(
    Brightness brightness, {
    bool listen = true,
  }) =>
      PrismThemeMapper.modeStyle(
        mode: _themeModeBloc(listen).state.mode.mode,
        brightness: brightness,
      );

  String prismModeStyleForContext({bool listen = true}) =>
      prismModeStyle(MediaQuery.of(this).platformBrightness, listen: listen);

  String prismModeStyleForWindow({bool listen = true}) =>
      prismModeStyle(WidgetsBinding.instance.platformDispatcher.platformBrightness, listen: listen);

  String prismModeAbs({bool listen = true}) =>
      PrismThemeMapper.modeAbsoluteLabel(_themeModeBloc(listen).state.mode.mode);

  bool prismIsAmoledDark({bool listen = true}) => prismDarkThemeId(listen: listen) == prismAmoledDarkThemeId;

  void setPrismThemeMode(String mode) {
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
