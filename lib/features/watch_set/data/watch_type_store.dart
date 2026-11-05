import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/logger/logger.dart';

const String watchFormatSettingsKey = 'watchSet.format';

/// The watch type the user picked last. Null before the first pick. Prism never detects the watch.
WatchFormat? rememberedWatchFormat() {
  if (!getIt.isRegistered<SettingsLocalDataSource>()) return null;
  try {
    return WatchFormat.fromId(getIt<SettingsLocalDataSource>().get<String?>(watchFormatSettingsKey, hasDefault: true));
  } catch (error, stackTrace) {
    logger.w('Could not read the watch type', error: error, stackTrace: stackTrace);
    return null;
  }
}

Future<void> rememberWatchFormat(WatchFormat format) async {
  if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
  try {
    await getIt<SettingsLocalDataSource>().set(watchFormatSettingsKey, format.id);
  } catch (error, stackTrace) {
    logger.w('Could not keep the watch type', error: error, stackTrace: stackTrace);
  }
}
