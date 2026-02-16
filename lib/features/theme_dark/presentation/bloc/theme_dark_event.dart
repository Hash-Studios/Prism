part of 'theme_dark_bloc.dart';

@freezed
abstract class ThemeDarkEvent with _$ThemeDarkEvent {
  const factory ThemeDarkEvent.started() = _Started;
  const factory ThemeDarkEvent.reloaded() = _Reloaded;
  const factory ThemeDarkEvent.themeChanged({required String themeId}) = _ThemeChanged;
  const factory ThemeDarkEvent.accentChanged({
    required int accentColorValue,
  }) = _AccentChanged;
}
