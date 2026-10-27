import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/theme_mode/data/legacy_themes.dart';
import 'package:Prism/features/theme_mode/data/repositories/theme_repository_impl.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_firestore_client.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/profile_user_fixture.dart';

class _ThrowingReadStore extends InMemoryLocalStore {
  @override
  Object? get(String key) => throw StateError('read failed');
}

/// The `usersv2/{uid}.themePrefs` wire shape.
Map<String, Object> _accountCopy({
  String mode = 'light',
  String lightId = 'kLCoffee',
  int lightAccent = 0xffc19439,
  String darkId = 'kDAMOLED',
  int darkAccent = 0xffffffff,
  required int changedAt,
}) => <String, Object>{
  'mode': mode,
  'lightThemeId': lightId,
  'lightAccent': lightAccent,
  'darkThemeId': darkId,
  'darkAccent': darkAccent,
  'changedAt': changedAt,
};

void main() {
  late InMemoryLocalStore store;
  late FakeFirestoreClient firestore;
  late ThemeRepositoryImpl repository;

  setUp(() {
    store = InMemoryLocalStore();
    firestore = FakeFirestoreClient();
    repository = ThemeRepositoryImpl(SettingsLocalDataSource(store), firestore);
    CoinsService.instance.inventoryNotifier.value = Inventory.empty;
  });

  tearDown(() {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    CoinsService.instance.inventoryNotifier.value = Inventory.empty;
  });

  test('returns the default themes and mode when nothing is stored', () async {
    final preferences = (await repository.load()).data!;
    final light = preferences.light;
    final dark = preferences.dark;

    expect(light.themeId, 'kLFrost White');
    expect(light.accentColorValue, 0xffe57697);
    expect(dark.themeId, 'kDMaterial Dark');
    expect(dark.accentColorValue, 0xffe57697);
    expect(preferences.mode, ThemeMode.system);
  });

  test('the first read stores the selected themes as legacy themes and later reads keep them', () async {
    store.data['settings.lightThemeID'] = 'kLRose';
    store.data['settings.darkThemeID'] = 'kDOlive';

    repository.readSync();
    await repository.update(lightThemeId: 'kLCoffee', darkThemeId: 'kDSky');
    repository.readSync();

    expect(store.data['settings.$legacyThemesSettingsKey'], 'kLRose,kDOlive');
    expect(readLegacyThemes(SettingsLocalDataSource(store)), <String>{'kLRose', 'kDOlive'});
  });

  test('an update before any read still records the themes that were selected before it', () async {
    store.data['settings.lightThemeID'] = 'kLRose';

    await repository.update(lightThemeId: 'kLCoffee');

    expect(readLegacyThemes(SettingsLocalDataSource(store)), <String>{'kLRose', 'kDMaterial Dark'});
  });

  test('without legacy themes nothing is grandfathered', () {
    expect(readLegacyThemes(SettingsLocalDataSource(store)), isEmpty);
  });

  test('setLightTheme stores the theme id and its default accent', () async {
    final result = await repository.update(lightThemeId: 'kLCoffee');

    expect(result.data!.light.themeId, 'kLCoffee');
    expect(result.data!.light.accentColorValue, 0xffc19439);
    expect(store.data['settings.lightThemeID'], 'kLCoffee');
    expect(store.data['settings.lightAccent'], 0xffc19439);
  });

  test('changing the theme keeps an accent the user picked', () async {
    await repository.update(lightAccentColorValue: 0xff123456);
    final result = await repository.update(lightThemeId: 'kLCoffee');

    expect(result.data!.light.themeId, 'kLCoffee');
    expect(result.data!.light.accentColorValue, 0xff123456);
  });

  test('changing the theme resets an accent that still equals the old theme default', () async {
    await repository.update(darkThemeId: 'kDOlive');
    final result = await repository.update(darkThemeId: 'kDSky');

    expect(result.data!.dark.accentColorValue, 0xff2d6079);
  });

  test('setDarkTheme gives AMOLED a white default accent', () async {
    final result = await repository.update(darkThemeId: 'kDAMOLED');

    expect(result.data!.dark.accentColorValue, 0xffffffff);
    expect(store.data['settings.darkThemeID'], 'kDAMOLED');
  });

  test('a stored black accent on AMOLED reads as the new default and is written back once', () async {
    await store.set('settings.darkThemeID', 'kDAMOLED');
    await store.set('settings.darkAccent', 0xff000000);

    final preferences = (await repository.load()).data!;

    expect(preferences.dark.accentColorValue, 0xffffffff);
    expect(store.data['settings.darkAccent'], 0xffffffff);
  });

  test('a stored black accent on AMOLED does not carry over to the next dark theme', () async {
    await store.set('settings.darkThemeID', 'kDAMOLED');
    await store.set('settings.darkAccent', 0xff000000);

    final result = await repository.update(darkThemeId: 'kDOlive');

    expect(result.data!.dark.accentColorValue, 0xff767b45);
  });

  test('a custom accent on AMOLED is left alone', () async {
    await store.set('settings.darkThemeID', 'kDAMOLED');
    await store.set('settings.darkAccent', 0xff123456);

    expect((await repository.load()).data!.dark.accentColorValue, 0xff123456);
    expect(store.data['settings.darkAccent'], 0xff123456);
  });

  test('readSync returns the stored selection without waiting', () async {
    await store.set('settings.lightThemeID', 'kLCoffee');
    await store.set('settings.themeMode', 'Light');

    final preferences = repository.readSync();

    expect(preferences.light.themeId, 'kLCoffee');
    expect(preferences.mode, ThemeMode.light);
  });

  test('an unknown theme id falls back to the default accent', () async {
    final result = await repository.update(lightThemeId: 'kLUnknown');

    expect(result.data!.light.themeId, 'kLUnknown');
    expect(result.data!.light.accentColorValue, 0xffe57697);
  });

  test('setLightAccent and setDarkAccent store only the accent', () async {
    await repository.update(lightAccentColorValue: 0xff123456);
    await repository.update(darkAccentColorValue: 0xff654321);

    expect(store.data['settings.lightAccent'], 0xff123456);
    expect(store.data['settings.darkAccent'], 0xff654321);
    expect(store.data.containsKey('settings.lightThemeID'), isFalse);
  });

  test('setThemeMode stores the label saved by earlier app versions', () async {
    await repository.update(mode: ThemeMode.system);
    expect(store.data['settings.themeMode'], 'System');

    await repository.update(mode: ThemeMode.light);
    expect(store.data['settings.themeMode'], 'Light');
    expect((await repository.load()).data!.mode, ThemeMode.light);
  });

  test('getThemeMode reads stored labels and treats an unknown label as dark', () async {
    await store.set('settings.themeMode', 'System');
    expect((await repository.load()).data!.mode, ThemeMode.system);

    await store.set('settings.themeMode', 'Purple');
    expect((await repository.load()).data!.mode, ThemeMode.dark);
  });

  test('read errors map to CacheFailure', () async {
    final failing = ThemeRepositoryImpl(SettingsLocalDataSource(_ThrowingReadStore()), firestore);

    expect((await failing.load()).failure, isA<CacheFailure>());
  });

  test('update while signed in writes the choice and its change time to the account', () async {
    app_state.prismUser = profileUser();

    await repository.update(lightThemeId: 'kLCoffee', darkThemeId: 'kDOlive', mode: ThemeMode.light);
    await pumpEventQueue();

    expect(firestore.writes.single.op, 'update');
    expect(firestore.writes.single.collection, FirebaseCollections.usersV2);
    expect(firestore.writes.single.id, 'u1');
    expect(firestore.writes.single.data, <String, Object?>{
      'themePrefs': <String, Object?>{
        'mode': 'light',
        'lightThemeId': 'kLCoffee',
        'lightAccent': 0xffc19439,
        'darkThemeId': 'kDOlive',
        'darkAccent': 0xff767b45,
        'changedAt': store.data['settings.theme.changed_at'],
      },
    });
  });

  test('update as a guest writes nothing to the account but stores the change time', () async {
    app_state.prismUser = profileUser(loggedIn: false);

    await repository.update(lightThemeId: 'kLCoffee');
    await pumpEventQueue();

    expect(firestore.writes, isEmpty);
    expect(store.data['settings.theme.changed_at'], isA<int>());
  });

  test('sync applies a newer account copy of free themes and emits it', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{'themePrefs': _accountCopy(changedAt: 1000)},
    };
    final List<ThemePreferences> emitted = <ThemePreferences>[];
    final StreamSubscription<ThemePreferences> subscription = repository.accountChanges.listen(emitted.add);
    addTearDown(subscription.cancel);

    await repository.syncWithAccount('u1');
    await pumpEventQueue();

    final ThemePreferences applied = repository.readSync();
    expect(applied.light.themeId, 'kLCoffee');
    expect(applied.light.accentColorValue, 0xffc19439);
    expect(applied.dark.themeId, 'kDAMOLED');
    expect(applied.dark.accentColorValue, 0xffffffff);
    expect(applied.mode, ThemeMode.light);
    expect(emitted.single.light.themeId, 'kLCoffee');
    expect(emitted.single.mode, ThemeMode.light);
    expect(store.data['settings.theme.changed_at'], 1000);
    expect(firestore.writes, isEmpty);
  });

  test('a second sync with the same account copy changes nothing and writes nothing', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{'themePrefs': _accountCopy(darkId: 'kDOlive', darkAccent: 0xff767b45, changedAt: 1000)},
    };

    await repository.syncWithAccount('u1');
    await repository.syncWithAccount('u1');

    final ThemePreferences applied = repository.readSync();
    expect(applied.light.themeId, 'kLCoffee');
    expect(applied.dark.themeId, 'kDMaterial Dark');
    expect(store.data['settings.theme.changed_at'], 1000);
    expect(firestore.writes, isEmpty);
  });

  test('sync keeps the local dark theme and accent when this device does not own the account dark theme', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{'themePrefs': _accountCopy(darkId: 'kDOlive', darkAccent: 0xff767b45, changedAt: 1000)},
    };
    store.data['settings.darkThemeID'] = 'kDAMOLED';
    store.data['settings.darkAccent'] = 0xff123456;

    await repository.syncWithAccount('u1');

    final ThemePreferences applied = repository.readSync();
    expect(applied.dark.themeId, 'kDAMOLED');
    expect(applied.dark.accentColorValue, 0xff123456);
    expect(applied.light.themeId, 'kLCoffee');
    expect(applied.mode, ThemeMode.light);
  });

  test('sync applies the account dark theme once this device owns it', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{'themePrefs': _accountCopy(darkId: 'kDOlive', darkAccent: 0xff767b45, changedAt: 1000)},
    };
    store.data['settings.darkThemeID'] = 'kDAMOLED';
    store.data['settings.darkAccent'] = 0xff123456;
    CoinsService.instance.inventoryNotifier.value = const Inventory(owned: <String>{'theme_olive'});

    await repository.syncWithAccount('u1');

    final ThemePreferences applied = repository.readSync();
    expect(applied.dark.themeId, 'kDOlive');
    expect(applied.dark.accentColorValue, 0xff767b45);
  });

  test('sync never turns the account paid theme into a legacy theme', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{'themePrefs': _accountCopy(darkId: 'kDOlive', darkAccent: 0xff767b45, changedAt: 1000)},
    };
    CoinsService.instance.inventoryNotifier.value = const Inventory(owned: <String>{'theme_olive'});

    await repository.syncWithAccount('u1');

    expect(repository.readSync().dark.themeId, 'kDOlive');
    expect(readLegacyThemes(SettingsLocalDataSource(store)), <String>{'kLFrost White', 'kDMaterial Dark'});
  });

  test('sync uploads the local choice when it changed after the account copy', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{'themePrefs': _accountCopy(changedAt: 1000)},
    };
    store.data['settings.lightThemeID'] = 'kLCoffee';
    store.data['settings.lightAccent'] = 0xffc19439;
    store.data['settings.darkThemeID'] = 'kDAMOLED';
    store.data['settings.darkAccent'] = 0xffffffff;
    store.data['settings.themeMode'] = 'Dark';
    store.data['settings.theme.changed_at'] = 2000;

    await repository.syncWithAccount('u1');

    expect(firestore.writes.single.op, 'update');
    expect(firestore.writes.single.data, <String, Object?>{
      'themePrefs': <String, Object?>{
        'mode': 'dark',
        'lightThemeId': 'kLCoffee',
        'lightAccent': 0xffc19439,
        'darkThemeId': 'kDAMOLED',
        'darkAccent': 0xffffffff,
        'changedAt': 2000,
      },
    });
    expect(store.data['settings.theme.changed_at'], 2000);
  });

  test('sync uploads a local change when the account has no copy', () async {
    app_state.prismUser = profileUser(loggedIn: false);
    await repository.update(lightThemeId: 'kLCoffee', mode: ThemeMode.light);
    app_state.prismUser = profileUser();

    await repository.syncWithAccount('u1');

    expect(firestore.writes.single.op, 'update');
    expect(firestore.writes.single.data, <String, Object?>{
      'themePrefs': <String, Object?>{
        'mode': 'light',
        'lightThemeId': 'kLCoffee',
        'lightAccent': 0xffc19439,
        'darkThemeId': 'kDMaterial Dark',
        'darkAccent': 0xffe57697,
        'changedAt': store.data['settings.theme.changed_at'],
      },
    });
  });

  test('sync with no account copy and no local change writes nothing', () async {
    await repository.syncWithAccount('u1');

    expect(firestore.writes, isEmpty);
    expect(store.data.containsKey('settings.theme.changed_at'), isFalse);
  });

  test('sync applies an account Material You copy and does not write it back', () async {
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'themePrefs': _accountCopy(
          lightId: 'kLMaterial You',
          lightAccent: 0xff111111,
          darkId: 'kDMaterial You',
          darkAccent: 0xff222222,
          changedAt: 1000,
        ),
      },
    };

    await repository.syncWithAccount('u1');

    final ThemePreferences applied = repository.readSync();
    expect(applied.light.themeId, 'kLMaterial You');
    expect(applied.light.accentColorValue, 0xff111111);
    expect(applied.dark.themeId, 'kDMaterial You');
    expect(applied.dark.accentColorValue, 0xff222222);
    expect(store.data['settings.theme.changed_at'], 1000);
    expect(firestore.writes, isEmpty);
  });

  test('a later dark change keeps the account Material You light theme', () async {
    app_state.prismUser = profileUser();
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
      'u1': <String, dynamic>{
        'themePrefs': _accountCopy(
          lightId: 'kLMaterial You',
          lightAccent: 0xff111111,
          darkId: 'kDMaterial You',
          darkAccent: 0xff222222,
          changedAt: 1000,
        ),
      },
    };
    await repository.syncWithAccount('u1');

    await repository.update(darkThemeId: 'kDAMOLED');
    await pumpEventQueue();

    expect(firestore.writes.single.op, 'update');
    final Map<String, Object?> pushed = firestore.writes.single.data!['themePrefs'] as Map<String, Object?>;
    expect(pushed['lightThemeId'], 'kLMaterial You');
    expect(pushed['darkThemeId'], 'kDAMOLED');
  });
}
