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
import 'package:Prism/features/theme_mode/seasonal_themes.dart';
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

  /// The accent after a theme change. It resets to the new theme default only while it still equals the default of the
  /// theme being replaced. A custom accent survives.
  int _accentAfterChange(List<PrismThemeOption> options, String previousThemeId, int? storedAccent, String newThemeId) {
    final int previousDefault = prismThemeById(options, previousThemeId)?.defaultAccentValue ?? prismDefaultAccentValue;
    final int currentAccent = storedAccent ?? previousDefault;
    final bool legacyAmoledAccent =
        previousThemeId == prismAmoledDarkThemeId && currentAccent == _legacyAmoledAccentValue;
    if (currentAccent != previousDefault && !legacyAmoledAccent) return currentAccent;
    return prismThemeById(options, newThemeId)?.defaultAccentValue ?? prismDefaultAccentValue;
  }

  Future<void> _rememberPreviousSeasonTheme(Brightness slot, String previousThemeId, String newThemeId) async {
    for (final SeasonalTheme season in seasonalThemes) {
      if (season.revertsAtEnd && season.themeIdFor(slot) == newThemeId && previousThemeId != newThemeId) {
        await _settingsLocal.set(season.previousThemeKey(slot), previousThemeId);
      }
    }
  }

  Future<void> _applyThemeChange({
    required Brightness slot,
    required String themeKey,
    required String accentKey,
    required String defaultThemeId,
    required List<PrismThemeOption> options,
    required String newThemeId,
  }) async {
    final String previousThemeId = _settingsLocal.get<String>(themeKey, defaultValue: defaultThemeId);
    final int? storedAccent = _settingsLocal.get<int?>(accentKey);
    final int accent = _accentAfterChange(options, previousThemeId, storedAccent, newThemeId);
    await _rememberPreviousSeasonTheme(slot, previousThemeId, newThemeId);
    if (accent != storedAccent) await _settingsLocal.set(accentKey, accent);
    await _settingsLocal.set(themeKey, newThemeId);
  }

  /// The selection for [slot] once [season] has ended: the theme the user had before the season theme, or the default
  /// theme. Only a choice made before the end reverts. The last theme change time tells, so a season theme picked after
  /// the end stays, and an old choice that comes back through the account sync reverts again. Null when nothing changes.
  ThemeSelection? _seasonRevert(SeasonalTheme season, Brightness slot, ThemeSelection current, DateTime now) {
    if (!season.revertsAtEnd || !season.window.hasEnded(now) || current.themeId != season.themeIdFor(slot)) return null;
    final int? changedAt = _settingsLocal.get<int?>(_changedAtKey);
    if (changedAt != null && !DateTime.fromMillisecondsSinceEpoch(changedAt).isBefore(season.window.end)) return null;
    final bool dark = slot == Brightness.dark;
    final String? previous = _settingsLocal.get<String?>(season.previousThemeKey(slot));
    final String themeId = previous == null || previous == current.themeId
        ? (dark ? prismDefaultDarkThemeId : prismDefaultLightThemeId)
        : previous;
    return ThemeSelection(
      themeId: themeId,
      accentColorValue: _accentAfterChange(
        dark ? prismDarkThemes : prismLightThemes,
        current.themeId,
        current.accentColorValue,
        themeId,
      ),
    );
  }

  /// [_read] with every ended season reverted. It writes nothing, so the first frame already shows the reverted theme.
  ThemePreferences _readReverted(DateTime now) {
    final ThemePreferences stored = _read();
    ThemeSelection light = stored.light;
    ThemeSelection dark = stored.dark;
    for (final SeasonalTheme season in seasonalThemes) {
      light = _seasonRevert(season, Brightness.light, light, now) ?? light;
      dark = _seasonRevert(season, Brightness.dark, dark, now) ?? dark;
    }
    return ThemePreferences(light: light, dark: dark, mode: stored.mode);
  }

  /// Saves the reverts of [_readReverted] on this device. It keeps the theme change time and uploads nothing, so a
  /// newer choice in the account still wins the next sync. The accent goes first, so a failed write retries cleanly.
  Future<ThemePreferences> _revertEndedSeasons() async {
    final ThemePreferences stored = _read();
    final ThemePreferences reverted = _readReverted(seasonNow());
    if (reverted.light.themeId != stored.light.themeId) {
      await _settingsLocal.set('lightAccent', reverted.light.accentColorValue);
      await _settingsLocal.set('lightThemeID', reverted.light.themeId);
    }
    if (reverted.dark.themeId != stored.dark.themeId) {
      await _settingsLocal.set('darkAccent', reverted.dark.accentColorValue);
      await _settingsLocal.set('darkThemeID', reverted.dark.themeId);
    }
    return _read();
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

  Future<void> _queue = Future<void>.value();

  /// Runs [operation] after every earlier load, update and sync step, so their reads and writes never interleave.
  Future<T> _serialized<T>(Future<T> Function() operation) {
    final Future<T> result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  ThemePreferences readSync() => _readReverted(seasonNow());

  @override
  Stream<ThemePreferences> get accountChanges => _accountChangesController.stream;

  @override
  Future<void> syncWithAccount(String userId) async {
    final ThemePreferences? revertedHere = await _serialized(() async {
      final ThemePreferences before = _read();
      final ThemePreferences after = await _revertEndedSeasons();
      if (before.light.themeId == after.light.themeId && before.dark.themeId == after.dark.themeId) return null;
      _accountChangesController.add(after);
      return after;
    });
    final AccountTheme? account = AccountTheme.fromMap(
      await _firestoreClient.getById<Object?>(
        FirebaseCollections.usersV2,
        userId,
        (data, _) => data[AccountTheme.field],
        sourceTag: 'theme_mode.read_account_theme',
      ),
    );
    // Decide on the local state after the read, so a theme change made while it ran is not lost.
    final AccountTheme? upload = await _serialized(() async {
      final ThemePreferences local = _read();
      final int? localChangedAt = _settingsLocal.get<int?>(_changedAtKey);
      if (account == null || (localChangedAt != null && account.changedAt < localChangedAt)) {
        return localChangedAt == null ? null : AccountTheme(preferences: local, changedAt: localChangedAt);
      }
      final ThemePreferences merged = mergeAccountTheme(
        account: account.preferences,
        local: local,
        owned: CoinsService.instance.inventoryNotifier.value.owned,
        legacyThemes: readLegacyThemes(_settingsLocal),
      );
      await _rememberPreviousSeasonTheme(Brightness.light, local.light.themeId, merged.light.themeId);
      await _rememberPreviousSeasonTheme(Brightness.dark, local.dark.themeId, merged.dark.themeId);
      await _settingsLocal.set('lightThemeID', merged.light.themeId);
      await _settingsLocal.set('lightAccent', merged.light.accentColorValue);
      await _settingsLocal.set('darkThemeID', merged.dark.themeId);
      await _settingsLocal.set('darkAccent', merged.dark.accentColorValue);
      await _settingsLocal.set('themeMode', _modeNames[merged.mode]);
      await _settingsLocal.set(_changedAtKey, account.changedAt);
      final ThemePreferences resolved = await _revertEndedSeasons();
      // An old season copy from the account reverts to what this sync already emitted. Do not emit it twice.
      final bool sameAsEmitted =
          revertedHere != null &&
          resolved.light.themeId == revertedHere.light.themeId &&
          resolved.dark.themeId == revertedHere.dark.themeId &&
          resolved.light.accentColorValue == revertedHere.light.accentColorValue &&
          resolved.dark.accentColorValue == revertedHere.dark.accentColorValue &&
          resolved.mode == revertedHere.mode;
      if (!sameAsEmitted) _accountChangesController.add(resolved);
      return null;
    });
    if (upload != null) await _push(userId, upload);
  }

  @override
  Future<Result<ThemePreferences>> load() => _serialized(() async {
    try {
      return Result.success(await _revertEndedSeasons());
    } catch (error) {
      return Result.error(CacheFailure('Unable to read theme: $error'));
    }
  });

  @override
  Future<Result<ThemePreferences>> update({
    String? lightThemeId,
    int? lightAccentColorValue,
    String? darkThemeId,
    int? darkAccentColorValue,
    ThemeMode? mode,
  }) => _serialized(() async {
    try {
      await _revertEndedSeasons();
      _rememberLegacyThemes();
      if (lightThemeId != null) {
        await _applyThemeChange(
          slot: Brightness.light,
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
          slot: Brightness.dark,
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
      final int changedAt = seasonNow().millisecondsSinceEpoch;
      await _settingsLocal.set(_changedAtKey, changedAt);
      final ThemePreferences preferences = _read();
      if (app_state.prismUser.loggedIn) {
        unawaited(_push(app_state.prismUser.id, AccountTheme(preferences: preferences, changedAt: changedAt)));
      }
      return Result.success(preferences);
    } catch (error) {
      return Result.error(CacheFailure('Unable to update theme: $error'));
    }
  });
}
