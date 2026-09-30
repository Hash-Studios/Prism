import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/theme_light/data/repositories/theme_repository_impl.dart';
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
    final light = (await repository.getLightTheme()).data!;
    final dark = (await repository.getDarkTheme()).data!;
    final mode = (await repository.getThemeMode()).data!;

    expect(light.themeId, 'kLFrost White');
    expect(light.accentColorValue, 0xffe57697);
    expect(dark.themeId, 'kDMaterial Dark');
    expect(dark.accentColorValue, 0xffe57697);
    expect(mode.mode, ThemeMode.dark);
  });

  test('setLightTheme stores the theme id and its default accent', () async {
    final result = await repository.setLightTheme('kLCoffee');

    expect(result.data!.themeId, 'kLCoffee');
    expect(result.data!.accentColorValue, 0xffc19439);
    expect(store.data['settings.lightThemeID'], 'kLCoffee');
    expect(store.data['settings.lightAccent'], 0xffc19439);
  });

  test('setDarkTheme keeps the AMOLED default accent', () async {
    final result = await repository.setDarkTheme('kDAMOLED');

    expect(result.data!.accentColorValue, 0xff000000);
    expect(store.data['settings.darkThemeID'], 'kDAMOLED');
  });

  test('an unknown theme id falls back to the default accent', () async {
    final result = await repository.setLightTheme('kLUnknown');

    expect(result.data!.themeId, 'kLUnknown');
    expect(result.data!.accentColorValue, 0xffe57697);
  });

  test('setLightAccent and setDarkAccent store only the accent', () async {
    await repository.setLightAccent(0xff123456);
    await repository.setDarkAccent(0xff654321);

    expect(store.data['settings.lightAccent'], 0xff123456);
    expect(store.data['settings.darkAccent'], 0xff654321);
    expect(store.data.containsKey('settings.lightThemeID'), isFalse);
  });

  test('setThemeMode stores the label saved by earlier app versions', () async {
    await repository.setThemeMode(ThemeMode.system);
    expect(store.data['settings.themeMode'], 'System');

    await repository.setThemeMode(ThemeMode.light);
    expect(store.data['settings.themeMode'], 'Light');
    expect((await repository.getThemeMode()).data!.mode, ThemeMode.light);
  });

  test('getThemeMode reads stored labels and treats an unknown label as dark', () async {
    await store.set('settings.themeMode', 'System');
    expect((await repository.getThemeMode()).data!.mode, ThemeMode.system);

    await store.set('settings.themeMode', 'Purple');
    expect((await repository.getThemeMode()).data!.mode, ThemeMode.dark);
  });

  test('read errors map to CacheFailure', () async {
    final failing = ThemeRepositoryImpl(SettingsLocalDataSource(_ThrowingReadStore()));

    expect((await failing.getLightTheme()).failure, isA<CacheFailure>());
    expect((await failing.getDarkTheme()).failure, isA<CacheFailure>());
    expect((await failing.getThemeMode()).failure, isA<CacheFailure>());
  });
}
