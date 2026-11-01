// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart' as auth_platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart' as core_platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_firestore_client.dart';
import '../support/profile_user_fixture.dart';

class _Core extends core_platform.FirebasePlatform {
  core_platform.FirebaseAppPlatform? initializedApp;

  @override
  List<core_platform.FirebaseAppPlatform> get apps => [if (initializedApp != null) initializedApp!];

  @override
  core_platform.FirebaseAppPlatform app([String name = '[DEFAULT]']) =>
      initializedApp ?? (throw FirebaseException(plugin: 'core', code: 'no-app'));

  @override
  Future<core_platform.FirebaseAppPlatform> initializeApp({String? name, FirebaseOptions? options}) async =>
      initializedApp = core_platform.FirebaseAppPlatform(name ?? '[DEFAULT]', options!);
}

class _MultiFactor extends auth_platform.MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends auth_platform.UserPlatform {
  _User(auth_platform.FirebaseAuthPlatform auth, String uid)
    : super(
        auth,
        _MultiFactor(auth),
        auth_platform.InternalUserDetails(
          userInfo: auth_platform.InternalUserInfo(uid: uid, isAnonymous: false, isEmailVerified: true),
          providerData: const <Map<Object?, Object?>?>[],
        ),
      );
}

class _Auth extends auth_platform.FirebaseAuthPlatform {
  String? uid;
  int signOutCalls = 0;

  @override
  auth_platform.FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  auth_platform.FirebaseAuthPlatform setInitialValues({
    auth_platform.InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  auth_platform.UserPlatform? get currentUser => uid == null ? null : _User(this, uid!);

  @override
  Future<void> signOut() async {
    signOutCalls++;
    uid = null;
  }
}

class _Google extends Fake implements GoogleSignIn {
  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}

  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) async =>
      throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);

  @override
  Future<void> signOut() async {}
}

class _Messaging extends Fake implements FirebaseMessaging {
  @override
  Future<String?> getAPNSToken() async => 'apns';
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
  @override
  Future<void> deleteToken() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Firebase initialization after sign-out clears the backend identity only for the current operation', () async {
    final previousCore = core_platform.FirebasePlatform.instance;
    final previousAuth = auth_platform.FirebaseAuthPlatform.instance;
    final platformAuth = _Auth();
    core_platform.FirebasePlatform.instance = _Core();
    auth_platform.FirebaseAuthPlatform.instance = platformAuth;
    final startup = Completer<bool>();
    FirebaseInit.setFuture(startup.future);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerSingleton<FirestoreClient>(FakeFirestoreClient());
    app_state.prismUser = profileUser();
    addTearDown(() async {
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      AnalyticsRuntime.reset();
      await getIt.reset();
      auth_platform.FirebaseAuthPlatform.instance = previousAuth;
      core_platform.FirebasePlatform.instance = previousCore;
    });
    final auth = GoogleAuth(googleSignIn: _Google(), messaging: _Messaging(), firebaseReady: () async => false);

    expect(await auth.signOutGoogle(), isTrue);
    expect(app_state.prismUser.id, isEmpty);
    expect(Firebase.apps, isEmpty);
    // The first deferred operation is now stale. Only this newer one may sign out Firebase later.
    expect(await auth.signOutGoogle(), isTrue);
    await Firebase.initializeApp(
      options: const FirebaseOptions(apiKey: 'test', appId: 'test', messagingSenderId: 'test', projectId: 'test'),
    );
    platformAuth.uid = 'u1';
    startup.complete(true);
    await FirebaseInit.readyFuture;
    await pumpEventQueue();

    expect(platformAuth.signOutCalls, 1);
    expect(FirebaseAuth.instance.currentUser, isNull);
    expect(app_state.prismUser.id, isEmpty);
  });
}
