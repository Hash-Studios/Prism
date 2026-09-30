import 'package:Prism/core/platform/wallpaper_service.dart';

class AutoRotateConfig {
  const AutoRotateConfig({
    this.enabled = false,
    this.intervalMinutes = 1440,
    this.target = WallpaperTarget.home,
    this.shuffle = true,
  });

  static const List<int> intervalOptions = <int>[60, 360, 720, 1440];

  final bool enabled;
  final int intervalMinutes;
  final WallpaperTarget target;
  final bool shuffle;

  AutoRotateConfig copyWith({bool? enabled, int? intervalMinutes, WallpaperTarget? target, bool? shuffle}) {
    return AutoRotateConfig(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      target: target ?? this.target,
      shuffle: shuffle ?? this.shuffle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AutoRotateConfig &&
      other.enabled == enabled &&
      other.intervalMinutes == intervalMinutes &&
      other.target == target &&
      other.shuffle == shuffle;

  @override
  int get hashCode => Object.hash(enabled, intervalMinutes, target, shuffle);
}

class AutoRotateStatus {
  const AutoRotateStatus({this.isRunning = false, this.nextRunEpochMs = 0, this.lastError});

  final bool isRunning;
  final int nextRunEpochMs;
  final String? lastError;

  @override
  bool operator ==(Object other) =>
      other is AutoRotateStatus &&
      other.isRunning == isRunning &&
      other.nextRunEpochMs == nextRunEpochMs &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(isRunning, nextRunEpochMs, lastError);
}
