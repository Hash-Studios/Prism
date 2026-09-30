part of 'auto_rotate_bloc.j.dart';

@freezed
abstract class AutoRotateState with _$AutoRotateState {
  const factory AutoRotateState({
    required bool loaded,
    required AutoRotateConfig config,
    required AutoRotateStatus status,
    required int favouriteCount,
    required bool isPro,
    required bool startFailed,
  }) = _AutoRotateState;

  factory AutoRotateState.initial() => const AutoRotateState(
    loaded: false,
    config: AutoRotateConfig(),
    status: AutoRotateStatus(),
    favouriteCount: 0,
    isPro: false,
    startFailed: false,
  );
}
