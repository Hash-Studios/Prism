import 'package:Prism/core/utils/result.dart';

/// What a person did with a wallpaper. The wire value is the `action` of the `recordWallpaperAction` callable.
enum WallpaperAction {
  download,
  set,
  share;

  String get wireValue => name;
}

/// Prism wallpaper view counters (Firestore-backed via Cloud Functions).
abstract class ViewStatsRepository {
  /// Increments the view count and returns the new total as a string for UI display.
  Future<Result<String>> recordWallpaperView(String wallId);

  /// Counts one [action] on the wall. An older backend without the callable counts as success, so the UI never breaks.
  Future<Result<void>> recordWallpaperAction(String wallId, WallpaperAction action);

  /// How many times the wall was set, from `wallpaper_stats`. Null when the wall has no stats yet.
  Future<Result<int?>> fetchWallpaperSetCount(String wallId);
}
