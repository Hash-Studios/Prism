import 'package:Prism/core/utils/result.dart';

/// Prism wallpaper view counters (Firestore-backed via Cloud Functions).
abstract class ViewStatsRepository {
  /// Increments the view count and returns the new total as a string for UI display.
  Future<Result<String>> recordWallpaperView(String wallId);
}
