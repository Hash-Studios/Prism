part of 'startup_bloc.dart';

@freezed
abstract class StartupState with _$StartupState {
  const factory StartupState({
    required LoadStatus status,
    required ActionStatus actionStatus,
    required StartupConfigEntity? config,
    required bool isObsoleteVersion,
    required double notchHeight,
    Failure? failure,
  }) = _StartupState;

  factory StartupState.initial() => const StartupState(
        status: LoadStatus.initial,
        actionStatus: ActionStatus.idle,
        config: null,
        isObsoleteVersion: false,
        notchHeight: 0,
      );
}
