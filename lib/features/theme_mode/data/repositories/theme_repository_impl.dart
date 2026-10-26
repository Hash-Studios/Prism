import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/theme_mode/data/account_theme.dart';
import 'package:Prism/features/theme_mode/data/legacy_themes.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/domain/repositories/theme_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ThemeRepository)
class ThemeRepositoryImpl implements ThemeRepository {
  ThemeRepositoryImpl(this._settingsLocal, this._firestoreClient);

  final SettingsLocalDataSource _settingsLocal;
  final FirestoreClient _firestoreClient;
  final StreamController<ThemePreferences> _accountChangesController = StreamController<ThemePreferences>.broadcast();

  static const int _legacyAmoledAccentValue = 0xff000000;

  static const String _changedAtKey = 'theme.changed_at';

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

  void _rememberLegacyThemes() => rememberLegacyThemes(
    _settingsLocal,
    lightId: _settingsLocal.get<String>('lightThemeID', defaultValue: prismDefaultLightThemeId),
    darkId: _settingsLocal.get<String>('darkThemeID', defaultValue: prismDefaultDarkThemeId),
  );

  ThemePreferences _read() {
    _rememberLegacyThemes();
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

  Future<void> _push(String userId, AccountTheme theme) async {
    try {
      await _firestoreClient.updateDoc(FirebaseCollections.usersV2, userId, {
        AccountTheme.field: theme.toMap(),
      }, sourceTag: 'theme_mode.push_account_theme');
    } catch (error, stackTrace) {
      logger.w('Theme did not upload to the account.', tag: 'Theme', error: error, stackTrace: stackTrace);
    }
  }

  @override
  ThemePreferences readSync() => _read();

  @override
  Stream<ThemePreferences> get accountChanges => _accountChangesController.stream;

  @override
  Future<void> syncWithAccount(String userId) async {
    final ThemePreferences local = _read();
    final AccountTheme? account = AccountTheme.fromMap(
      await _firestoreClient.getById<Object?>(
        FirebaseCollections.usersV2,
        userId,
        (data, _) => data[AccountTheme.field],
        sourceTag: 'theme_mode.read_account_theme',
      ),
    );
    final int? localChangedAt = _settingsLocal.get<int?>(_changedAtKey);
    if (account != null && (localChangedAt == null || account.changedAt >= localChangedAt)) {
      final ThemePreferences merged = mergeAccountTheme(
        account: account.preferences,
        local: local,
        owned: CoinsService.instance.inventoryNotifier.value.owned,
        legacyThemes: readLegacyThemes(_settingsLocal),
      );
      await _settingsLocal.set('lightThemeID', merged.light.themeId);
      await _settingsLocal.set('lightAccent', merged.light.accentColorValue);
      await _settingsLocal.set('darkThemeID', merged.dark.themeId);
      await _settingsLocal.set('darkAccent', merged.dark.accentColorValue);
      await _settingsLocal.set('themeMode', _modeNames[merged.mode]);
      await _settingsLocal.set(_changedAtKey, account.changedAt);
      _accountChangesController.add(_read());
    } else if (localChangedAt != null) {
      await _push(userId, AccountTheme(preferences: local, changedAt: localChangedAt));
    }
  }

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
      _rememberLegacyThemes();
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
      final int changedAt = DateTime.now().millisecondsSinceEpoch;
      await _settingsLocal.set(_changedAtKey, changedAt);
      final ThemePreferences preferences = _read();
      if (app_state.prismUser.loggedIn) {
        unawaited(_push(app_state.prismUser.id, AccountTheme(preferences: preferences, changedAt: changedAt)));
      }
      return Result.success(preferences);
    } catch (error) {
      return Result.error(CacheFailure('Unable to update theme: $error'));
    }
  }
}
