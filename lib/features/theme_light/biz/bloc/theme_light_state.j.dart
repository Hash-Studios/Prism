part of 'theme_light_bloc.j.dart';

@freezed
abstract class ThemeLightState with _$ThemeLightState {
  const factory ThemeLightState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required ThemeLightEntity theme,
    Failure? failure,
  }) = _ThemeLightState;

  factory ThemeLightState.initial() => const ThemeLightState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        theme: ThemeLightEntity(
          themeId: 'kLFrost White',
          accentColorValue: 0xffe57697,
        ),
      );
}
