import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/features/startup/data/repositories/startup_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

void main() {
  late SettingsLocalDataSource settings;

  setUpAll(() {
    FirebaseInit.setFuture(Future<bool>.value(false));
  });

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
  });

  tearDown(() => getIt.reset());

  test('startup without Firebase preserves the last reported obsolete version', () async {
    await settings.set(PersistenceKeys.obsoleteAppVersion, '99.0.0');

    final result = await StartupRepositoryImpl().bootstrap();

    expect(result.isSuccess, isTrue);
    expect(result.data!.obsoleteAppVersion, '99.0.0');
    expect(settings.get<String>(PersistenceKeys.obsoleteAppVersion), '99.0.0');
  });

  test('hardcoded fallback does not grant a later launch the cached fast path', () async {
    final result = await StartupRepositoryImpl().bootstrap();

    expect(result.isSuccess, isTrue);
    expect(settings.get<String>(PersistenceKeys.obsoleteAppVersion, defaultValue: ''), isEmpty);
  });

  test('an empty cached version still uses the hardcoded minimum', () async {
    await settings.set(PersistenceKeys.obsoleteAppVersion, '');

    final result = await StartupRepositoryImpl().bootstrap();

    expect(result.data!.obsoleteAppVersion, defaultObsoleteAppVersion);
  });

  test('an empty or blank remote value uses the cached version', () {
    expect(resolveObsoleteVersion('', '99.0.0'), '99.0.0');
    expect(resolveObsoleteVersion('  ', '99.0.0'), '99.0.0');
    expect(resolveObsoleteVersion(' ', ''), defaultObsoleteAppVersion);
    expect(resolveObsoleteVersion(' 5.0.0 ', '99.0.0'), '5.0.0');
  });
}
