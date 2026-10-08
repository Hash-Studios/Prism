part of 'auto_rotate_bloc.j.dart';

@freezed
abstract class AutoRotateState with _$AutoRotateState {
  const factory AutoRotateState({
    required bool loaded,
    required AutoRotateConfig config,
    required AutoRotateStatus status,
    required int favouriteCount,
    required int downloadCount,
    required bool sourcesCapped,
    required bool isPro,
    required bool startFailed,
    required bool starting,
    required bool showBatteryTip,
  }) = _AutoRotateState;

  const AutoRotateState._();

  int get sourceCount => config.source == AutoRotateSource.downloads ? downloadCount : favouriteCount;

  factory AutoRotateState.initial() => const AutoRotateState(
    loaded: false,
    config: AutoRotateConfig(),
    status: AutoRotateStatus(),
    favouriteCount: 0,
    downloadCount: 0,
    sourcesCapped: false,
    isPro: false,
    startFailed: false,
    starting: false,
    showBatteryTip: false,
  );
}
