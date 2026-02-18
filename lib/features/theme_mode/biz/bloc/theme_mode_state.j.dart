part of 'theme_mode_bloc.j.dart';

@freezed
abstract class ThemeModeState with _$ThemeModeState {
  const factory ThemeModeState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required ThemeModeEntity mode,
    Failure? failure,
  }) = _ThemeModeState;

  factory ThemeModeState.initial() => const ThemeModeState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    mode: ThemeModeEntity(mode: 'Dark'),
  );
}
