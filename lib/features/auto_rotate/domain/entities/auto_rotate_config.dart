import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/data/categories/category_definition.dart';

enum AutoRotateSource { favourites, downloads, category, wallOfTheDay, history }

/// The categories the picker offers. Same names as the discover grid.
final List<String> autoRotateCategories = List<String>.unmodifiable(prismClassifierCategories);

class AutoRotateConfig {
  const AutoRotateConfig({
    this.enabled = false,
    this.intervalMinutes = 1440,
    this.target = WallpaperTarget.home,
    this.shuffle = true,
    this.source = AutoRotateSource.favourites,
    this.categoryName = 'Nature',
    this.chargingOnly = false,
  });

  static const List<int> intervalOptions = <int>[15, 30, 60, 180, 360, 720, 1440, 4320, 10080];

  final bool enabled;
  final int intervalMinutes;
  final WallpaperTarget target;
  final bool shuffle;
  final AutoRotateSource source;
  final String categoryName;
  final bool chargingOnly;

  AutoRotateConfig copyWith({
    bool? enabled,
    int? intervalMinutes,
    WallpaperTarget? target,
    bool? shuffle,
    AutoRotateSource? source,
    String? categoryName,
    bool? chargingOnly,
  }) {
    return AutoRotateConfig(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      target: target ?? this.target,
      shuffle: shuffle ?? this.shuffle,
      source: source ?? this.source,
      categoryName: categoryName ?? this.categoryName,
      chargingOnly: chargingOnly ?? this.chargingOnly,
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
      other.categoryName == categoryName &&
      other.chargingOnly == chargingOnly;

  @override
  int get hashCode => Object.hash(enabled, intervalMinutes, target, shuffle, source, categoryName, chargingOnly);
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
