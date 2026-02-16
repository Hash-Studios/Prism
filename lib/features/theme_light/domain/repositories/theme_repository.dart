import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_dark/domain/entities/theme_dark.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';

abstract class ThemeRepository {
  Future<Result<ThemeLightEntity>> getLightTheme();

  Future<Result<ThemeLightEntity>> setLightTheme(String themeId);

  Future<Result<ThemeLightEntity>> setLightAccent(int colorValue);

  Future<Result<ThemeDarkEntity>> getDarkTheme();

  Future<Result<ThemeDarkEntity>> setDarkTheme(String themeId);

  Future<Result<ThemeDarkEntity>> setDarkAccent(int colorValue);

  Future<Result<ThemeModeEntity>> getThemeMode();

  Future<Result<ThemeModeEntity>> setThemeMode(String mode);
}
