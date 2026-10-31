// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/debug/creator_stats_emulator.dart';
import 'package:Prism/env/env.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Core extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(String name, CoreFirebaseOptions options) async =>
      CoreInitializeResponse(name: name, options: options, pluginConstants: {});
}

class _Auth extends FirebaseAuthPlatform {
  String? host;
  int? port;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({String? languageCode, InternalUserDetails? currentUser}) => this;

  @override
  Future<void> useAuthEmulator(String host, int port) async {
    this.host = host;
    this.port = port;
  }
}

class _Firestore extends FirebaseFirestorePlatform {
  @override
  FirebaseFirestorePlatform delegateFor({required FirebaseApp app, required String databaseId}) => this;

  @override
  Settings settings = const Settings();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bootstrap rejects unsafe builds and projects before connecting, or preserves the Android loopback host',
    () async {
      if (kDebugMode) {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
      }
      TestFirebaseCoreHostApi.setUp(_Core());
      final auth = _Auth();
      final firestore = _Firestore();
      FirebaseAuthPlatform.instance = auth;
      FirebaseFirestorePlatform.instance = firestore;

      if (!kDebugMode || !Env.creatorStatsEmulator) {
        await expectLater(CreatorStatsEmulator.connect(), throwsStateError);
        await expectLater(CreatorStatsEmulator.signIn(), throwsStateError);
      } else if (Env.creatorStatsEmulatorProject != 'demo-prism') {
        await expectLater(CreatorStatsEmulator.connect(), throwsArgumentError);
      } else if (Env.skipFirebaseInit) {
        await expectLater(CreatorStatsEmulator.connect(), throwsStateError);
      } else {
        await CreatorStatsEmulator.connect();
        expect(Firebase.app().options.projectId, 'demo-prism');
        expect(auth.host, '127.0.0.1');
        expect(auth.port, 9099);
        expect(FirebaseFirestore.instance.settings.host, '127.0.0.1:8080');
        expect(FirebaseFirestore.instance.settings.sslEnabled, isFalse);
        expect(FirebaseFirestore.instance.settings.persistenceEnabled, isFalse);
        expect(appFunctions.httpsCallable('getCreatorStats').delegate.origin, 'http://127.0.0.1:5001');

        await Firebase.initializeApp(
          name: 'non-demo',
          options: const FirebaseOptions(
            apiKey: 'key',
            appId: 'app',
            messagingSenderId: 'sender',
            projectId: 'production',
          ),
        );
        auth.host = null;
        await expectLater(CreatorStatsEmulator.connect(), throwsStateError);
      }
      expect(auth.host, isNull, reason: 'Rejected bootstraps must not reach the Auth emulator');
    },
  );
}
