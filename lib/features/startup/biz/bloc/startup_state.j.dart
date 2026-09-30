part of 'startup_bloc.j.dart';

@freezed
abstract class StartupState with _$StartupState {
  const factory StartupState({
    required LoadStatus status,
    required StartupConfigEntity? config,
    required bool isObsoleteVersion,
  }) = _StartupState;

  factory StartupState.initial() =>
      const StartupState(status: LoadStatus.initial, config: null, isObsoleteVersion: false);
}
