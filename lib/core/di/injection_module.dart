import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/core/persistence/local_store.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

@module
abstract class AppModule {
  @lazySingleton
  FirebaseFirestore get firebaseFirestore => FirebaseFirestore.instance;

  @lazySingleton
  FirestoreTelemetrySink get firestoreTelemetrySink => CompositeFirestoreTelemetrySink(<FirestoreTelemetrySink>[
    if (kDebugMode) const FirestoreConsoleTelemetrySink(),
    FirestoreFileTelemetrySink(),
  ]);

  @lazySingleton
  FirestoreClient firestoreClient(FirebaseFirestore firestore, FirestoreTelemetrySink telemetrySink) =>
      FirestoreTrackedClient(firestore, telemetrySink);

  @lazySingleton
  FirebaseRemoteConfig get remoteConfig => FirebaseRemoteConfig.instance;

  @lazySingleton
  InternetConnectionChecker get internetConnectionChecker => InternetConnectionChecker.instance;

  @lazySingleton
  LocalStore get localStore => PersistenceRuntime.store;
}
