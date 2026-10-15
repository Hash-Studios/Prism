part of 'auto_rotate_bloc.j.dart';

@freezed
abstract class AutoRotateState with _$AutoRotateState {
  const factory AutoRotateState({
    required bool loaded,
    required AutoRotateConfig config,
    required AutoRotateStatus status,
    required int favouriteCount,
    required int downloadCount,
    required int remoteCount,
    required bool sourcesCapped,
    required bool isPro,
    required bool startFailed,
    required bool starting,
    required bool showBatteryTip,
    required bool loadingSource,
    required bool sourceLoadFailed,
    required bool proLapsed,
    required Set<WallpaperTarget> supportedTargets,
  }) = _AutoRotateState;

  const AutoRotateState._();

  int get sourceCount => switch (config.source) {
    AutoRotateSource.favourites => favouriteCount,
    AutoRotateSource.downloads => downloadCount,
    AutoRotateSource.category || AutoRotateSource.wallOfTheDay || AutoRotateSource.history => remoteCount,
  };

  factory AutoRotateState.initial() => const AutoRotateState(
    loaded: false,
    config: AutoRotateConfig(),
    status: AutoRotateStatus(),
    favouriteCount: 0,
    downloadCount: 0,
    remoteCount: 0,
    sourcesCapped: false,
    isPro: false,
    startFailed: false,
    starting: false,
    showBatteryTip: false,
    loadingSource: false,
    sourceLoadFailed: false,
    proLapsed: false,
    supportedTargets: <WallpaperTarget>{WallpaperTarget.home, WallpaperTarget.lock, WallpaperTarget.both},
  );
}
