import 'dart:convert';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/debug/local_qa_adapters.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/local_qa_firestore.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/migrations/persistence_migration_runner.dart';
import 'package:Prism/core/persistence/persistence_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/env/env.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class LocalQaRuntime {
  LocalQaRuntime._();
  static final store = LocalQaStore(Env.localQaUser);
  static const project = 'demo-prism';
  static const password = 'local-demo-only-password';
  static String get uid => Env.localQaUser == 'creator' ? 'qa-creator-a' : 'qa-viewer';

  static void installNetworkPolicy() {
    if (!kDebugMode || !Env.localQa || Env.skipFirebaseInit || kIsWeb) {
      throw StateError('Local QA requires a mobile debug build with Firebase initialization enabled.');
    }
    if (!const <String>{'viewer', 'creator', 'guest'}.contains(Env.localQaUser)) {
      throw StateError('Unknown local QA identity.');
    }
    if (base64Decode(Env.localQaCertificate).isEmpty) throw StateError('Missing exact fixture DER certificate.');
    HttpOverrides.global = _LocalQaHttpOverrides();
    AnalyticsRuntime.instance = const NoopAppAnalytics();
  }

  static Future<void> initializePersistence() async {
    await store.init();
    await PersistenceMigrationRunner.run(store);
    PersistenceRuntime.store = store;
  }

  static Future<void> initializeFirebase() async {
    for (final app in Firebase.apps) {
      if (app.options.projectId != project) throw StateError('A non-demo Firebase app already exists.');
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: 'AIzaSy000000000000000000000000000000000',
        appId: defaultTargetPlatform == TargetPlatform.iOS
            ? '1:1234567890:ios:0123456789abcdef'
            : '1:1234567890:android:0123456789abcdef',
        messagingSenderId: '1234567890',
        projectId: project,
        storageBucket: 'demo-prism.appspot.com',
        iosBundleId: 'com.hash.prism',
      ),
    );
    if (Firebase.app().options.projectId != project) throw StateError('Wrong Firebase project.');
    await FirebaseAuth.instance.useAuthEmulator('localhost', 19371, automaticHostMapping: false);
    configureLocalQaFirestore();
    for (final region in const <String>['us-central1', 'asia-south1']) {
      FirebaseFunctions.instanceFor(
        region: region,
      ).useFunctionsEmulator('localhost', 19373, automaticHostMapping: false);
    }
    await FirebaseAuth.instance.signOut();
    if (Env.localQaUser != 'guest') {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: '$uid@example.test',
        password: password,
      );
      if (credential.user?.uid != uid || credential.user?.isAnonymous != false) {
        throw StateError('Unexpected emulator identity. Run the local seed first.');
      }
    }
  }

  static Future<void> _replace<T extends Object>(T value) async {
    if (getIt.isRegistered<T>()) await getIt.unregister<T>();
    getIt.registerSingleton<T>(value);
  }

  static Future<void> installDependenciesAndSession() async {
    await _replace<ConnectivityService>(LocalQaConnectivity());
    await _replace<AdsRepository>(LocalQaAds());
    await _replace<PexelsWallpaperRepository>(LocalQaPexels());
    await _replace<WallhavenWallpaperRepository>(LocalQaWallhaven());
    await _replace<StartupRepository>(LocalQaStartup());
    final settings = getIt<SettingsLocalDataSource>();
    await settings.set('onboarded_v2_new', true);
    await settings.set('onboarding_v2_interests', <String>['Nature']);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await getIt<FirestoreClient>().getById<Map<String, dynamic>>(
        'usersv2',
        user.uid,
        (data, _) => data,
        sourceTag: 'LocalQaRuntime.profile',
      );
      if (profile == null) throw StateError('Missing emulator profile. Run seed first.');
      final result = await getIt<SessionRepository>().replaceCurrentUser(PrismUsersV2.fromMapWithUser(profile, user));
      if (result.isFailure) throw StateError('Unable to persist local session: ${result.failure}');
    }
    validateSession();
  }

  static bool validateSession() {
    final user = FirebaseAuth.instance.currentUser;
    final session = app_state.prismUser;
    if (Env.localQaUser == 'guest') {
      if (user != null || session.loggedIn) throw StateError('Guest session mismatch.');
      return false;
    }
    if (user?.uid != uid || session.id != uid || !session.loggedIn || user?.email != session.email) {
      throw StateError('Local Auth and persisted session disagree.');
    }
    return true;
  }
}

class _LocalQaHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      if (proxyHost != null ||
          !const <String>{'localhost', '127.0.0.1', '10.0.2.2', '::1'}.contains(uri.host) ||
          !const <int>{19371, 19372, 19373, 19374, 19375}.contains(uri.port)) {
        throw StateError('Local QA refused network connection to ${uri.origin}.');
      }
      if (uri.scheme == 'https') {
        return SecureSocket.startConnect(
          uri.host,
          uri.port,
          context: context,
          onBadCertificate: (certificate) =>
              uri.host == 'localhost' && uri.port == 19375 && base64Encode(certificate.der) == Env.localQaCertificate,
        );
      }
      return Socket.startConnect(uri.host, uri.port);
    };
    client.badCertificateCallback = (certificate, host, port) =>
        host == 'localhost' && port == 19375 && base64Encode(certificate.der) == Env.localQaCertificate;
    return client;
  }
}
