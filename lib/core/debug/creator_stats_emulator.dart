import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/di/injection_module.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/env/env.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore_sdk;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Explicit local-only QA bootstrap. Failures stop startup rather than fall back.
class CreatorStatsEmulator {
  CreatorStatsEmulator._();

  static final _firebaseModule = _EmulatorFirebaseModule();

  static bool get enabled => kDebugMode && Env.creatorStatsEmulator;

  static void validate({required String project, required String host, required String account}) {
    if (project != 'demo-prism' ||
        !const {'127.0.0.1', 'localhost', '::1', '10.0.2.2'}.contains(host) ||
        !const {'creator', 'other', 'empty'}.contains(account)) {
      throw ArgumentError('Creator stats QA requires demo-prism, a local host and creator/other/empty account.');
    }
  }

  static Future<void> connect() async {
    if (!enabled) throw StateError('Emulator bootstrap requires an opt-in debug build.');
    validate(
      project: Env.creatorStatsEmulatorProject,
      host: Env.creatorStatsEmulatorHost,
      account: Env.creatorStatsEmulatorAccount,
    );
    if (Env.skipFirebaseInit) throw StateError('Do not combine emulator QA with SKIP_FIREBASE_INIT.');
    for (final existing in Firebase.apps) {
      if (existing.options.projectId != 'demo-prism') throw StateError('A non-demo Firebase app already exists.');
    }
    final app = await Firebase.initializeApp(options: options(defaultTargetPlatform));
    if (app.options.projectId != 'demo-prism') throw StateError('Refusing a non-demo Firebase app.');
    const host = Env.creatorStatsEmulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    _firebaseModule.firebaseFirestore.settings = const firestore_sdk.Settings(persistenceEnabled: false);
    _firebaseModule.firebaseFirestore.useFirestoreEmulator(host, 8080);
    appFunctions.useFunctionsEmulator(host, 5001);
  }

  /// Must equal the native demo config written by `tool/creator_stats_qa/native.cjs`.
  static FirebaseOptions options(TargetPlatform platform) => FirebaseOptions(
    apiKey: 'AIzaSyDemoPrismLocalOnly00000000000000000',
    appId: platform == TargetPlatform.iOS
        ? '1:123456789012:ios:0000000000000000000000'
        : '1:123456789012:android:0000000000000000000000',
    messagingSenderId: '123456789012',
    projectId: 'demo-prism',
    storageBucket: 'demo-prism.appspot.com',
    iosBundleId: 'com.hash.prism',
  );

  static FirestoreClient localFirestore() =>
      FirestoreTrackedClient(_firebaseModule.firebaseFirestore, const FirestoreConsoleTelemetrySink());

  static Future<void> installFirestore() async {
    await getIt.unregister<FirestoreClient>();
    getIt.registerSingleton<FirestoreClient>(localFirestore());
  }

  static Future<void> signIn() async {
    if (!enabled) throw StateError('Emulator sign-in requires an opt-in debug build.');
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: '${Env.creatorStatsEmulatorAccount}@demo-prism.test',
      password: 'local-prism-qa-only',
    );
    final user = credential.user!;
    final FirestoreClient firestore = localFirestore();
    final profile = await firestore.getById<Map<String, dynamic>>(
      'usersv2',
      user.uid,
      (data, _) => data,
      sourceTag: 'debug.creator_stats_emulator.profile',
    );
    if (profile == null) throw StateError('Seed the demo user profile before launching QA.');
    await SessionLocalDataSource(
      PersistenceRuntime.store,
    ).writeCurrentUser(PrismUsersV2.fromMapWithUser(profile, user));
  }
}

class _EmulatorFirebaseModule extends AppModule {}
