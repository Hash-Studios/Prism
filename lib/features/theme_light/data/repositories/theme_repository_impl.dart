import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_dark/domain/entities/theme_dark.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_light/domain/repositories/theme_repository.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ThemeRepository)
class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this._settingsLocal);

  final SettingsLocalDataSource _settingsLocal;

  static const Map<ThemeMode, String> _modeNames = <ThemeMode, String>{
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
    ThemeMode.system: 'System',
  };

  ThemeMode _parseMode(String name) =>
      _modeNames.entries.where((entry) => entry.value == name).firstOrNull?.key ?? ThemeMode.dark;

  ThemeLightEntity _readLightTheme() {
    return ThemeLightEntity(
      themeId: _settingsLocal.get<String>('lightThemeID', defaultValue: prismDefaultLightThemeId),
      accentColorValue: _settingsLocal.get<int>('lightAccent', defaultValue: prismDefaultAccentValue),
    );
  }

  ThemeDarkEntity _readDarkTheme() {
    return ThemeDarkEntity(
      themeId: _settingsLocal.get<String>('darkThemeID', defaultValue: prismDefaultDarkThemeId),
      accentColorValue: _settingsLocal.get<int>('darkAccent', defaultValue: prismDefaultAccentValue),
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
      await _settingsLocal.set('lightThemeID', themeId);
      await _settingsLocal.set(
        'lightAccent',
        prismThemeById(prismLightThemes, themeId)?.defaultAccentValue ?? prismDefaultAccentValue,
      );
      return Result.success(_readLightTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to set light theme: $error'));
    }
  }

  @override
  Future<Result<ThemeLightEntity>> setLightAccent(int colorValue) async {
    try {
      await _settingsLocal.set('lightAccent', colorValue);
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
      await _settingsLocal.set('darkThemeID', themeId);
      await _settingsLocal.set(
        'darkAccent',
        prismThemeById(prismDarkThemes, themeId)?.defaultAccentValue ?? prismDefaultAccentValue,
      );
      return Result.success(_readDarkTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to set dark theme: $error'));
    }
  }

  @override
  Future<Result<ThemeDarkEntity>> setDarkAccent(int colorValue) async {
    try {
      await _settingsLocal.set('darkAccent', colorValue);
      return Result.success(_readDarkTheme());
    } catch (error) {
      return Result.error(CacheFailure('Unable to set dark accent: $error'));
    }
  }

  @override
  Future<Result<ThemeModeEntity>> getThemeMode() async {
    try {
      final name = _settingsLocal.get<String>('themeMode', defaultValue: _modeNames[ThemeMode.dark]);
      return Result.success(ThemeModeEntity(mode: _parseMode(name)));
    } catch (error) {
      return Result.error(CacheFailure('Unable to read mode: $error'));
    }
  }

  @override
  Future<Result<ThemeModeEntity>> setThemeMode(ThemeMode mode) async {
    try {
      await _settingsLocal.set('themeMode', _modeNames[mode]);
      return Result.success(ThemeModeEntity(mode: mode));
    } catch (error) {
      return Result.error(CacheFailure('Unable to set mode: $error'));
    }
  }
}
