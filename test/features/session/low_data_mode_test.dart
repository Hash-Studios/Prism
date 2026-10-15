import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    LowDataMode.enabled.value = false;
    await getIt.reset();
  });

  test('is off until the user turns it on', () {
    expect(LowDataMode.enabled.value, isFalse);
  });

  test('set saves the choice and tells listeners at once', () async {
    final seen = <bool>[];
    void listener() => seen.add(LowDataMode.enabled.value);
    LowDataMode.enabled.addListener(listener);
    addTearDown(() => LowDataMode.enabled.removeListener(listener));

    await LowDataMode.set(true);

    expect(LowDataMode.enabled.value, isTrue);
    expect(seen.last, isTrue);
    expect(getIt<SettingsLocalDataSource>().get<bool>(LowDataMode.settingsKey, defaultValue: false), isTrue);

    await LowDataMode.set(false);
    expect(LowDataMode.enabled.value, isFalse);
    expect(getIt<SettingsLocalDataSource>().get<bool>(LowDataMode.settingsKey, defaultValue: true), isFalse);
  });
}
