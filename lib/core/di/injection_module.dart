import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/updates/code_push_updater.dart';
import 'package:Prism/core/updates/ota_update_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show Sentry;

@module
abstract class AppModule {
  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  FirestoreTelemetrySink get firestoreTelemetrySink => CompositeFirestoreTelemetrySink(<FirestoreTelemetrySink>[
    if (kDebugMode || kProfileMode) const FirestoreConsoleTelemetrySink(),
    FirestoreFileTelemetrySink(),
  ]);

  @lazySingleton
  FirestoreClient firestoreClient(FirestoreTelemetrySink telemetrySink) =>
      FirestoreTrackedClient.deferred(() => FirebaseFirestore.instance, telemetrySink);

  @lazySingleton
  FirebaseRemoteConfig get remoteConfig => FirebaseRemoteConfig.instance;

  @lazySingleton
  InternetConnectionChecker get internetConnectionChecker => buildInternetConnectionChecker();

  @lazySingleton
  LocalStore get localStore => PersistenceRuntime.store;

  @lazySingleton
  CodePushUpdater codePushUpdater(SettingsLocalDataSource settings) =>
      ShorebirdCodePushUpdater(track: () => settings.get<String>(OtaUpdateController.trackKey, defaultValue: 'stable'));

  @lazySingleton
  OtaUpdateController otaUpdateController(CodePushUpdater updater, SettingsLocalDataSource settings) =>
      OtaUpdateController(
        updater: updater,
        settings: settings,
        analytics: analytics,
        release: () => (version: app_state.currentAppVersion, build: app_state.currentAppVersionCode),
        tagPatch: (int patchNumber) =>
            Sentry.configureScope((scope) => scope.setTag('shorebird_patch', '$patchNumber')),
      );
}
