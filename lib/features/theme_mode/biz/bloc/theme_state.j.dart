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
  }) = _ThemeState;

  factory ThemeState.initial() => const ThemeState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    light: ThemeSelection(themeId: prismDefaultLightThemeId, accentColorValue: prismDefaultAccentValue),
    dark: ThemeSelection(themeId: prismDefaultDarkThemeId, accentColorValue: prismDefaultAccentValue),
    mode: ThemeMode.system,
  );
}
