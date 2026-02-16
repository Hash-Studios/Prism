import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_dark/domain/entities/theme_dark.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_light/domain/repositories/theme_repository.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ThemeRepository)
class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(@Named('prefsBox') this._prefsBox);

  final Box<dynamic> _prefsBox;

  static const String _defaultLightTheme = 'kLFrost White';
  static const String _defaultDarkTheme = 'kDMaterial Dark';
  static const int _defaultAccent = 0xffe57697;
  static const String _defaultMode = 'Dark';
  static const Map<String, int> _lightThemeDefaultAccents = <String, int>{
    'kLFrost White': 0xffe57697,
    'kLCoffee': 0xffc19439,
    'kLRose': 0xffa7796d,
    'kLCotton Blue': 0xff596f95,
  };
  static const Map<String, int> _darkThemeDefaultAccents = <String, int>{
    'kDMaterial Dark': 0xffe57697,
    'kDAMOLED': 0xff000000,
    'kDOlive': 0xff767b45,
    'kDDeep Ocean': 0xff427da8,
    'kDJungle': 0xff4c7044,
    'kDPepper': 0xff703826,
    'kDSky': 0xff2d6079,
    'kDSteel': 0xff686e80,
  };

  ThemeLightEntity _readLightTheme() {
    return ThemeLightEntity(
      themeId: (_prefsBox.get('lightThemeID', defaultValue: _defaultLightTheme) as String?) ?? _defaultLightTheme,
      accentColorValue: (_prefsBox.get('lightAccent', defaultValue: _defaultAccent) as int?) ?? _defaultAccent,
    );
  }

  ThemeDarkEntity _readDarkTheme() {
    return ThemeDarkEntity(
      themeId: (_prefsBox.get('darkThemeID', defaultValue: _defaultDarkTheme) as String?) ?? _defaultDarkTheme,
      accentColorValue: (_prefsBox.get('darkAccent', defaultValue: _defaultAccent) as int?) ?? _defaultAccent,
    );
  }

  @override
  Future<Result<ThemeLightEntity>> getLightTheme() async {
    try {
      return Result.success(_readLightTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to read light theme: $error'));
    }
  }

  @override
  Future<Result<ThemeLightEntity>> setLightTheme(String themeId) async {
    try {
      await _prefsBox.put('lightThemeID', themeId);
      await _prefsBox.put('lightAccent', _lightThemeDefaultAccents[themeId] ?? _defaultAccent);
      return Result.success(_readLightTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to set light theme: $error'));
    }
  }

  @override
  Future<Result<ThemeLightEntity>> setLightAccent(int colorValue) async {
    try {
      await _prefsBox.put('lightAccent', colorValue);
      return Result.success(_readLightTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to set light accent: $error'));
    }
  }

  @override
  Future<Result<ThemeDarkEntity>> getDarkTheme() async {
    try {
      return Result.success(_readDarkTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to read dark theme: $error'));
    }
  }

  @override
  Future<Result<ThemeDarkEntity>> setDarkTheme(String themeId) async {
    try {
      await _prefsBox.put('darkThemeID', themeId);
      await _prefsBox.put('darkAccent', _darkThemeDefaultAccents[themeId] ?? _defaultAccent);
      return Result.success(_readDarkTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to set dark theme: $error'));
    }
  }

  @override
  Future<Result<ThemeDarkEntity>> setDarkAccent(int colorValue) async {
    try {
      await _prefsBox.put('darkAccent', colorValue);
      return Result.success(_readDarkTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to set dark accent: $error'));
    }
  }

  @override
  Future<Result<ThemeModeEntity>> getThemeMode() async {
    try {
      final mode = (_prefsBox.get('themeMode', defaultValue: _defaultMode) as String?) ?? _defaultMode;
      return Result.success(ThemeModeEntity(mode: mode));
    } catch (error) {
      return Result.error(CacheFailure('Unable to read mode: $error'));
    }
  }

  @override
  Future<Result<ThemeModeEntity>> setThemeMode(String mode) async {
    const allowedModes = <String>{'Light', 'Dark', 'System'};
    if (!allowedModes.contains(mode)) {
      return Result.error(const ValidationFailure('Theme mode must be Light, Dark, or System'));
    }

    try {
      await _prefsBox.put('themeMode', mode);
      return Result.success(ThemeModeEntity(mode: mode));
    } catch (error) {
      return Result.error(CacheFailure('Unable to set mode: $error'));
    }
  }
}
