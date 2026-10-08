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

  /// Returns true once, the first time it is called.
  Future<bool> consumeBatteryTip();
}
