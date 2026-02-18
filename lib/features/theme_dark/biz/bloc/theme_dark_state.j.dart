part of 'theme_dark_bloc.j.dart';

@freezed
abstract class ThemeDarkState with _$ThemeDarkState {
  const factory ThemeDarkState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required ThemeDarkEntity theme,
    Failure? failure,
  }) = _ThemeDarkState;

  factory ThemeDarkState.initial() => const ThemeDarkState(
    status: LoadStatus.initial,
    actionStatus: ActionStatus.idle,
    theme: ThemeDarkEntity(themeId: 'kDMaterial Dark', accentColorValue: 0xffe57697),
  );
}
