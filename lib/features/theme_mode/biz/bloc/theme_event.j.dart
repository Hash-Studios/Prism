part of 'theme_bloc.j.dart';

@freezed
abstract class ThemeEvent with _$ThemeEvent {
  const factory ThemeEvent.started() = _Started;
  const factory ThemeEvent.lightThemeChanged({required String themeId}) = _LightThemeChanged;
  const factory ThemeEvent.lightAccentChanged({required int accentColorValue}) = _LightAccentChanged;
  const factory ThemeEvent.darkThemeChanged({required String themeId}) = _DarkThemeChanged;
  const factory ThemeEvent.darkAccentChanged({required int accentColorValue}) = _DarkAccentChanged;
  const factory ThemeEvent.modeChanged({required ThemeMode mode}) = _ModeChanged;
}
