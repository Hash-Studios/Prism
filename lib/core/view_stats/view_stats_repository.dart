import 'package:Prism/core/utils/result.dart';

/// Prism wallpaper and setup view counters (Firestore-backed via Cloud Functions).
abstract class ViewStatsRepository {
  /// Increments the view count and returns the new total as a string for UI display.
  Future<Result<String>> recordWallpaperView(String wallId);

  /// Increments the view count and returns the new total as a string for UI display.
  Future<Result<String>> recordSetupView(String setupId);
}
