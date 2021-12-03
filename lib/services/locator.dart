import 'package:get_it/get_it.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/services/theme_pref_service.dart';
import 'package:prism/services/theme_service.dart';

import 'logger.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  Stopwatch stopwatch = Stopwatch()..start();
  locator.registerFactory<ThemeController>(() => ThemeController());
  locator.registerLazySingleton<ThemeService>(() => ThemeServicePrefs());
  logger.d('Locator setup took ${stopwatch.elapsedMilliseconds} ms');
  stopwatch.stop();
}
