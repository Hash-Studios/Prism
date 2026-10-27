import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_color_scheme.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Applies the user accent to [baseTheme]. An accent that nearly matches the theme background (black on AMOLED)
/// is replaced by the theme's own accent. The colour scheme and the chip theme follow the accent.
ThemeData withPrismAccent(ThemeData baseTheme, int accentColorValue) {
  final ColorScheme base = baseTheme.colorScheme;
  Color accentColor = Color(accentColorValue);
  if (contrastRatio(accentColor, baseTheme.primaryColor) < 1.5) {
    accentColor = base.primary;
  }
  return baseTheme.withPrismScheme(
    prismColorScheme(
      brightness: base.brightness,
      background: base.surface,
      foreground: base.onSurface,
      accent: accentColor,
    ),
  );
}

/// The theme [state] shows for [brightness], with the user accent when that theme takes one.
ThemeData prismThemeFor(ThemeState state, Brightness brightness) {
  final PrismThemeOption option = state.themeOption(brightness);
  if (!option.usesAccent) return option.theme;
  final ThemeSelection selection = brightness == Brightness.dark ? state.dark : state.light;
  return withPrismAccent(option.theme, selection.accentColorValue);
}

String _modeAbsoluteLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.light => l10n.wallpaperThemeModeLight,
  ThemeMode.dark => l10n.wallpaperThemeModeDark,
  ThemeMode.system => l10n.wallpaperThemeModeSystem,
};

extension PrismThemeContextX on BuildContext {
  ThemeState _themeState(bool listen) => (listen ? watch<ThemeBloc>() : read<ThemeBloc>()).state;

  ThemeData prismLightTheme({bool listen = true}) => prismThemeFor(_themeState(listen), Brightness.light);

  ThemeData prismDarkTheme({bool listen = true}) => prismThemeFor(_themeState(listen), Brightness.dark);

  String prismLightThemeId({bool listen = true}) => _themeState(listen).light.themeId;

  String prismDarkThemeId({bool listen = true}) => _themeState(listen).dark.themeId;

  int prismLightAccentValue({bool listen = true}) => _themeState(listen).light.accentColorValue;

  int prismDarkAccentValue({bool listen = true}) => _themeState(listen).dark.accentColorValue;

  ThemeMode prismThemeMode({bool listen = true}) => _themeState(listen).mode;

  String prismModeAbs(AppLocalizations l10n, {bool listen = true}) =>
      _modeAbsoluteLabel(l10n, _themeState(listen).mode);

  void setPrismThemeMode(ThemeMode mode) {
    read<ThemeBloc>().add(ThemeEvent.modeChanged(mode: mode));
  }

  void setPrismLightTheme(String themeId) {
    read<ThemeBloc>().add(ThemeEvent.lightThemeChanged(themeId: themeId));
  }

  void setPrismDarkTheme(String themeId, {ThemeMode? mode}) {
    read<ThemeBloc>().add(ThemeEvent.darkThemeChanged(themeId: themeId, mode: mode));
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
