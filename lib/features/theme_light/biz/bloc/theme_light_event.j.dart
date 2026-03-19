part of 'theme_light_bloc.j.dart';

@freezed
abstract class ThemeLightEvent with _$ThemeLightEvent {
  const factory ThemeLightEvent.started() = _Started;
  const factory ThemeLightEvent.reloaded() = _Reloaded;
  const factory ThemeLightEvent.themeChanged({required String themeId}) = _ThemeChanged;
  const factory ThemeLightEvent.accentChanged({required int accentColorValue}) = _AccentChanged;
}
