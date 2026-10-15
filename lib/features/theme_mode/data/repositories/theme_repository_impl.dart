import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/domain/repositories/theme_repository.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ThemeRepository)
class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this._settingsLocal);

  final SettingsLocalDataSource _settingsLocal;

  static const int _legacyAmoledAccentValue = 0xff000000;

  static const Map<ThemeMode, String> _modeNames = <ThemeMode, String>{
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
    ThemeMode.system: 'System',
  };

  ThemeMode _parseMode(String name) =>
      _modeNames.entries.where((entry) => entry.value == name).firstOrNull?.key ?? ThemeMode.dark;

  /// Builds before the AMOLED default became white stored black as the accent. Black on AMOLED is invisible,
  /// so it counts as "no custom accent": read the new default and write it back once.
  int _readDarkAccent() {
    final String darkThemeId = _settingsLocal.get<String>('darkThemeID', defaultValue: prismDefaultDarkThemeId);
    final int stored = _settingsLocal.get<int>('darkAccent', defaultValue: prismDefaultAccentValue);
    if (darkThemeId != prismAmoledDarkThemeId || stored != _legacyAmoledAccentValue) return stored;
    final int corrected = prismThemeById(prismDarkThemes, prismAmoledDarkThemeId)!.defaultAccentValue;
    unawaited(_settingsLocal.set('darkAccent', corrected));
    return corrected;
  }

  ThemePreferences _read() {
    return ThemePreferences(
      light: ThemeSelection(
        themeId: _settingsLocal.get<String>('lightThemeID', defaultValue: prismDefaultLightThemeId),
        accentColorValue: _settingsLocal.get<int>('lightAccent', defaultValue: prismDefaultAccentValue),
      ),
      dark: ThemeSelection(
        themeId: _settingsLocal.get<String>('darkThemeID', defaultValue: prismDefaultDarkThemeId),
        accentColorValue: _readDarkAccent(),
      ),
      mode: _parseMode(_settingsLocal.get<String>('themeMode', defaultValue: _modeNames[ThemeMode.system])),
    );
  }

  /// A theme change resets the accent to the new theme default only while the accent still
  /// equals the default of the theme being replaced. A custom accent survives.
  Future<void> _applyThemeChange({
    required String themeKey,
    required String accentKey,
    required String defaultThemeId,
    required List<PrismThemeOption> options,
    required String newThemeId,
  }) async {
    final String previousThemeId = _settingsLocal.get<String>(themeKey, defaultValue: defaultThemeId);
    final int previousDefault = prismThemeById(options, previousThemeId)?.defaultAccentValue ?? prismDefaultAccentValue;
    final int currentAccent = _settingsLocal.get<int>(accentKey, defaultValue: previousDefault);
    await _settingsLocal.set(themeKey, newThemeId);
    final bool legacyAmoledAccent =
        previousThemeId == prismAmoledDarkThemeId && currentAccent == _legacyAmoledAccentValue;
    if (currentAccent == previousDefault || legacyAmoledAccent) {
      await _settingsLocal.set(
        accentKey,
        prismThemeById(options, newThemeId)?.defaultAccentValue ?? prismDefaultAccentValue,
      );
    }
  }

  @override
  ThemePreferences readSync() => _read();

  @override
  Future<Result<ThemePreferences>> load() async {
    try {
      return Result.success(_read());
    } catch (error) {
      return Result.error(CacheFailure('Unable to read theme: $error'));
    }
  }

  @override
  Future<Result<ThemePreferences>> update({
    String? lightThemeId,
    int? lightAccentColorValue,
    String? darkThemeId,
    int? darkAccentColorValue,
    ThemeMode? mode,
  }) async {
    try {
      if (lightThemeId != null) {
        await _applyThemeChange(
          themeKey: 'lightThemeID',
          accentKey: 'lightAccent',
          defaultThemeId: prismDefaultLightThemeId,
          options: prismLightThemes,
          newThemeId: lightThemeId,
        );
      }
      if (lightAccentColorValue != null) {
        await _settingsLocal.set('lightAccent', lightAccentColorValue);
      }
      if (darkThemeId != null) {
        await _applyThemeChange(
          themeKey: 'darkThemeID',
          accentKey: 'darkAccent',
          defaultThemeId: prismDefaultDarkThemeId,
          options: prismDarkThemes,
          newThemeId: darkThemeId,
        );
      }
      if (darkAccentColorValue != null) {
        await _settingsLocal.set('darkAccent', darkAccentColorValue);
      }
      if (mode != null) {
        await _settingsLocal.set('themeMode', _modeNames[mode]);
      }
      return Result.success(_read());
    } catch (error) {
      return Result.error(CacheFailure('Unable to update theme: $error'));
    }
  }
}
