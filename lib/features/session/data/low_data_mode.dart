import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:flutter/foundation.dart';

/// The Data saver switch in Settings. When it is on, the detail screen loads the thumbnail first, the feed does not
/// prefetch images, and carousels do not autoplay. Screens read [enabled] and listen to it.
// ignore: avoid_classes_with_only_static_members
abstract final class LowDataMode {
  static const String settingsKey = 'lowDataMode';

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(_readStored());

  static bool _readStored() {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return false;
      final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
      return settings.isOpen && settings.get<bool>(settingsKey, defaultValue: false);
    } catch (_) {
      return false;
    }
  }

  /// Saves the choice and tells every listener.
  static Future<void> set(bool value) async {
    enabled.value = value;
    await getIt<SettingsLocalDataSource>().set(settingsKey, value);
  }
}
