import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/data/categories/category_definition.dart';

enum AutoRotateSource { favourites, downloads, category, wallOfTheDay, history, folder }

/// Why the app turned a folder rotation off by itself.
enum AutoRotateStopReason { folderDeleted, folderEmpty }

/// A folder rotation the app turned off, shown to the user once.
typedef AutoRotateFolderStop = ({AutoRotateStopReason reason, String folderName});

/// The analytics bucket for a folder's wall count.
String folderCountBucket(int count) => switch (count) {
  <= 1 => '$count',
  <= 5 => '2-5',
  <= 20 => '6-20',
  <= 50 => '21-50',
  _ => '51+',
};

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
    this.passUntil,
    this.folderId,
    this.folderName = '',
  });

  static const List<int> intervalOptions = <int>[15, 30, 60, 180, 360, 720, 1440, 4320, 10080];

  final bool enabled;
  final int intervalMinutes;
  final WallpaperTarget target;
  final bool shuffle;
  final AutoRotateSource source;
  final String categoryName;
  final bool chargingOnly;

  /// The folder to rotate when [source] is [AutoRotateSource.folder].
  final String? folderId;

  /// The folder's name when it was picked, for display only.
  final String folderName;

  /// End of the coin pass that allows the rotation. Null for Pro, or when no pass is known.
  final DateTime? passUntil;

  /// The pass that allowed the rotation has ended.
  bool passExpired(DateTime now) => passUntil != null && !passUntil!.isAfter(now);

  AutoRotateConfig copyWith({
    bool? enabled,
    int? intervalMinutes,
    WallpaperTarget? target,
    bool? shuffle,
    AutoRotateSource? source,
    String? categoryName,
    bool? chargingOnly,
    DateTime? Function()? passUntil,
    String? Function()? folderId,
    String? folderName,
  }) {
    return AutoRotateConfig(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      target: target ?? this.target,
      shuffle: shuffle ?? this.shuffle,
      source: source ?? this.source,
      categoryName: categoryName ?? this.categoryName,
      chargingOnly: chargingOnly ?? this.chargingOnly,
      passUntil: passUntil == null ? this.passUntil : passUntil(),
      folderId: folderId == null ? this.folderId : folderId(),
      folderName: folderName ?? this.folderName,
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
      other.chargingOnly == chargingOnly &&
      other.passUntil == passUntil &&
      other.folderId == folderId &&
      other.folderName == folderName;

  @override
  int get hashCode => Object.hash(
    enabled,
    intervalMinutes,
    target,
    shuffle,
    source,
    categoryName,
    chargingOnly,
    passUntil,
    folderId,
    folderName,
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
