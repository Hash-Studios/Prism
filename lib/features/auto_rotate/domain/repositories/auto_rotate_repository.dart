import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';

abstract class AutoRotateRepository {
  Future<AutoRotateConfig> loadConfig();

  Future<void> saveConfig(AutoRotateConfig config);

  /// Returns false when the platform refused to start the rotation.
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls);

  /// Returns false when the platform could not stop the rotation.
  Future<bool> stop();

  Future<AutoRotateStatus> status();

  /// Returns false when the platform could not change the wallpaper.
  Future<bool> rotateNow();

  /// The sources the platform was last started with, or null when unknown.
  Future<List<String>?> loadAppliedSources();

  /// Paths of the wallpapers the user downloaded. Empty when they cannot be listed.
  Future<List<String>> listDownloads();

  /// Image URLs for a source that the repository loads itself: a category, the Wall of the Day archive or the apply
  /// history. The order is stable for the same data, so reopening the app does not restart the rotation. Returns null
  /// when the list could not be loaded, and an empty list for the other sources.
  Future<List<String>?> loadRemoteUrls(AutoRotateSource source, {String? category});

  /// The wallpaper targets this device can set. All of them when the device does not say.
  Future<Set<WallpaperTarget>> supportedTargets();

  /// Returns true once, the first time it is called.
  Future<bool> consumeBatteryTip();
}
