import 'package:Prism/core/platform/wallpaper_service.dart';

enum AutoRotateSource { favourites, downloads }

class AutoRotateConfig {
  const AutoRotateConfig({
    this.enabled = false,
    this.intervalMinutes = 1440,
    this.target = WallpaperTarget.home,
    this.shuffle = true,
    this.source = AutoRotateSource.favourites,
    this.chargingOnly = false,
    this.activeHoursEnabled = false,
    this.activeHoursStart = 6,
    this.activeHoursEnd = 23,
  });

  static const List<int> intervalOptions = <int>[60, 360, 720, 1440];

  final bool enabled;
  final int intervalMinutes;
  final WallpaperTarget target;
  final bool shuffle;
  final AutoRotateSource source;
  final bool chargingOnly;
  final bool activeHoursEnabled;
  final int activeHoursStart;
  final int activeHoursEnd;

  AutoRotateConfig copyWith({
    bool? enabled,
    int? intervalMinutes,
    WallpaperTarget? target,
    bool? shuffle,
    AutoRotateSource? source,
    bool? chargingOnly,
    bool? activeHoursEnabled,
    int? activeHoursStart,
    int? activeHoursEnd,
  }) {
    return AutoRotateConfig(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      target: target ?? this.target,
      shuffle: shuffle ?? this.shuffle,
      source: source ?? this.source,
      chargingOnly: chargingOnly ?? this.chargingOnly,
      activeHoursEnabled: activeHoursEnabled ?? this.activeHoursEnabled,
      activeHoursStart: activeHoursStart ?? this.activeHoursStart,
      activeHoursEnd: activeHoursEnd ?? this.activeHoursEnd,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AutoRotateConfig &&
      other.enabled == enabled &&
      other.intervalMinutes == intervalMinutes &&
      other.target == target &&
      other.shuffle == shuffle &&
      other.source == source &&
      other.chargingOnly == chargingOnly &&
      other.activeHoursEnabled == activeHoursEnabled &&
      other.activeHoursStart == activeHoursStart &&
      other.activeHoursEnd == activeHoursEnd;

  @override
  int get hashCode => Object.hash(
    enabled,
    intervalMinutes,
    target,
    shuffle,
    source,
    chargingOnly,
    activeHoursEnabled,
    activeHoursStart,
    activeHoursEnd,
  );
}

class AutoRotateStatus {
  const AutoRotateStatus({
    this.isRunning = false,
    this.nextRunEpochMs = 0,
    this.lastError,
    this.cachedCount = 0,
    this.totalCount = 0,
  });

  final bool isRunning;
  final int nextRunEpochMs;
  final String? lastError;
  final int cachedCount;
  final int totalCount;

  @override
  bool operator ==(Object other) =>
      other is AutoRotateStatus &&
      other.isRunning == isRunning &&
      other.nextRunEpochMs == nextRunEpochMs &&
      other.lastError == lastError &&
      other.cachedCount == cachedCount &&
      other.totalCount == totalCount;

  @override
  int get hashCode => Object.hash(isRunning, nextRunEpochMs, lastError, cachedCount, totalCount);
}
