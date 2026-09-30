import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';

abstract class AutoRotateRepository {
  Future<AutoRotateConfig> loadConfig();

  Future<void> saveConfig(AutoRotateConfig config);

  /// Returns false when the platform refused to start the rotation.
  Future<bool> start(AutoRotateConfig config, List<String> imageUrls);

  Future<void> stop();

  Future<AutoRotateStatus> status();

  /// Returns false when the platform could not change the wallpaper.
  Future<bool> rotateNow();
}
