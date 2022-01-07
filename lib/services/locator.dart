import 'package:get_it/get_it.dart';
import 'package:prism/controllers/hide_controller.dart';
import 'package:prism/controllers/setup_controller.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/controllers/wallhaven_controller.dart';
import 'package:prism/router/app_router.dart';
import 'package:prism/services/hide_service.dart';
import 'package:prism/services/palette_generator_service.dart';
import 'package:prism/services/settings_service.dart';
import 'package:prism/services/setup_service.dart';
import 'package:prism/services/theme_pref_service.dart';
import 'package:prism/services/theme_service.dart';
import 'package:prism/services/wallhaven_api.dart';
import 'package:prism/services/wallhaven_service.dart';

import 'logger.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  Stopwatch stopwatch = Stopwatch()..start();
  locator.registerFactory<ThemeController>(() => ThemeController());
  locator.registerFactory<WallHavenController>(() => WallHavenController());
  locator.registerFactory<SetupController>(() => SetupController());
  locator.registerFactory<HideController>(() => HideController());
  locator.registerSingleton<AppRouter>(AppRouter());
  locator.registerLazySingleton<ThemeService>(() => ThemeServicePrefs());
  locator.registerLazySingleton<WallHavenAPI>(() => WallHavenAPI());
  locator.registerLazySingleton<WallHavenService>(() => WallHavenService());
  locator.registerLazySingleton<SetupService>(() => SetupService());
  locator.registerLazySingleton<SettingsService>(() => SettingsService());
  locator.registerLazySingleton<PaletteGeneratorService>(
      () => PaletteGeneratorService());
  locator.registerLazySingleton<HideService>(() => HideService());
  logger.d('Locator setup took ${stopwatch.elapsedMilliseconds} ms');
  stopwatch.stop();
}
