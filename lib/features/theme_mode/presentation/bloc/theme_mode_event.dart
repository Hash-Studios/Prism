part of 'theme_mode_bloc.dart';

@freezed
abstract class ThemeModeEvent with _$ThemeModeEvent {
  const factory ThemeModeEvent.started() = _Started;
  const factory ThemeModeEvent.modeChanged({required String mode}) =
      _ModeChanged;
}
