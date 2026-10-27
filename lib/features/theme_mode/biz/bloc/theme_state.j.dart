part of 'theme_bloc.j.dart';

@freezed
abstract class ThemeState with _$ThemeState {
  const factory ThemeState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required ThemeSelection light,
    required ThemeSelection dark,
    required ThemeMode mode,
    Failure? failure,

    /// The phone's Material You schemes. Null where the phone has none.
    SystemColorSchemes? system,
  }) = _ThemeState;

  factory ThemeState.initial() => const ThemeState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    light: ThemeSelection(themeId: prismDefaultLightThemeId, accentColorValue: prismDefaultAccentValue),
    dark: ThemeSelection(themeId: prismDefaultDarkThemeId, accentColorValue: prismDefaultAccentValue),
    mode: ThemeMode.system,
  );

  factory ThemeState.fromPreferences(ThemePreferences preferences) =>
      ThemeState.initial().copyWith(light: preferences.light, dark: preferences.dark, mode: preferences.mode);
}

extension ThemeStateOptions on ThemeState {
  /// The theme option shown for [brightness]. A theme this device cannot show resolves to the default one.
  PrismThemeOption themeOption(Brightness brightness) =>
      resolvePrismThemeOption((brightness == Brightness.dark ? dark : light).themeId, brightness, system);
}
