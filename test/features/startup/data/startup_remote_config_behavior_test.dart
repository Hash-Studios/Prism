import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/features/startup/data/repositories/startup_repository_impl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/in_memory_local_store.dart';

class _Config extends FirebaseRemoteConfigPlatform {
  bool failPreparation = false;
  bool failRead = false;
  int rollout = 150;

  @override
  FirebaseRemoteConfigPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseRemoteConfigPlatform setInitialValues({required Map<Object?, Object?> remoteConfigValues}) => this;
  @override
  Future<void> setConfigSettings(RemoteConfigSettings remoteConfigSettings) async {
    if (failPreparation) throw StateError('offline');
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {}
  @override
  Future<bool> activate() async => true;
  @override
  Future<bool> fetchAndActivate() async => true;
  @override
  DateTime get lastFetchTime => DateTime.now();
  @override
  RemoteConfigFetchStatus get lastFetchStatus => RemoteConfigFetchStatus.success;
  @override
  String getString(String key) {
    if (failRead) throw StateError('corrupt config');
    return switch (key) {
      'obsoleteVersion' => ' 9.1.0 ',
      'verifiedUsers' => '["creator-a", "creator-b",]',
      'premiumCollections' => ' ',
      'bannerTextOn' => 'true',
      _ => 'campaign-$key',
    };
  }

  @override
  bool getBool(String key) => key != 'ai_submit_enabled';
  @override
  int getInt(String key) => rollout;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Config config;
  late SettingsLocalDataSource settings;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    config = _Config();
    FirebaseRemoteConfigPlatform.instance = config;
    FirebaseInit.setFuture(Future<bool>.value(true));
    await FirebaseInit.readyFuture;
  });
  setUp(() {
    config
      ..failPreparation = false
      ..failRead = false
      ..rollout = 150;
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<FirestoreClient>(FakeFirestoreClient());
    EconomyConfig.resetForTest();
  });
  tearDown(() async {
    await getIt.reset();
    EconomyConfig.resetForTest();
  });

  test('remote bootstrap normalizes lists, bounds rollout and caches the minimum version', () async {
    final repository = StartupRepositoryImpl();
    final result = await repository.bootstrap();
    expect(result.isSuccess, isTrue);
    final value = result.data!;
    expect(value.verifiedUsers, <String>['creator-a', 'creator-b']);
    expect(value.premiumCollections, isEmpty);
    expect(value.aiRolloutPercent, 100);
    expect(value.aiEnabled, isTrue);
    expect(value.aiSubmitEnabled, isFalse);
    expect(value.bannerText, 'campaign-bannerText');
    expect(value.bannerTextOn, isTrue);
    expect(value.obsoleteAppVersion, '9.1.0');
    expect(repository.currentConfig, same(value));
    expect(settings.get<String>(PersistenceKeys.obsoleteAppVersion), '9.1.0');
  });

  test('failed preparation still uses activated config and clamps negative rollout', () async {
    config
      ..failPreparation = true
      ..rollout = -10;
    final result = await StartupRepositoryImpl().bootstrap();
    expect(result.isSuccess, isTrue);
    expect(result.data!.aiRolloutPercent, 0);
    expect(result.data!.obsoleteAppVersion, '9.1.0');
  });

  test('unreadable config returns a failure without replacing the current config', () async {
    final repository = StartupRepositoryImpl();
    final previous = (await repository.bootstrap()).data;
    config.failRead = true;
    final result = await repository.bootstrap();
    expect(result.isSuccess, isFalse);
    expect(result.failure!.message, contains('corrupt config'));
    expect(repository.currentConfig, same(previous));
  });
}
