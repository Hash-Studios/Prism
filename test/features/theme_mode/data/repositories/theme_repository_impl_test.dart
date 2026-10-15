import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/theme_mode/data/repositories/theme_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_local_store.dart';

class _ThrowingReadStore extends InMemoryLocalStore {
  @override
  Object? get(String key) => throw StateError('read failed');
}

void main() {
  late InMemoryLocalStore store;
  late ThemeRepositoryImpl repository;

  setUp(() {
    store = InMemoryLocalStore();
    repository = ThemeRepositoryImpl(SettingsLocalDataSource(store));
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
    final failing = ThemeRepositoryImpl(SettingsLocalDataSource(_ThrowingReadStore()));

    expect((await failing.load()).failure, isA<CacheFailure>());
  });
}
