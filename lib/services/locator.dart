import 'package:get_it/get_it.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/router/app_router.dart';
import 'package:prism/services/theme_pref_service.dart';
import 'package:prism/services/theme_service.dart';
import 'package:prism/services/wallhaven_api.dart';
import 'package:prism/services/wallhaven_service.dart';

import 'logger.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  Stopwatch stopwatch = Stopwatch()..start();
  locator.registerFactory<ThemeController>(() => ThemeController());
  locator.registerSingleton<AppRouter>(AppRouter());
  locator.registerLazySingleton<ThemeService>(() => ThemeServicePrefs());
  locator.registerLazySingleton<WallHavenAPI>(() => WallHavenAPI());
  locator.registerLazySingleton<WallHavenService>(() => WallHavenService());
  logger.d('Locator setup took ${stopwatch.elapsedMilliseconds} ms');
  stopwatch.stop();
}
