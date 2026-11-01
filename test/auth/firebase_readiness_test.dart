// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/auth/apple_auth.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/data/repositories/session_repository_impl.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart' as auth_platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';
import '../support/profile_user_fixture.dart';

class _Core extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(String name, CoreFirebaseOptions options) async =>
      CoreInitializeResponse(name: name, options: options, pluginConstants: {});
}

class _MultiFactor extends auth_platform.MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _PlatformUser extends auth_platform.UserPlatform {
  _PlatformUser(auth_platform.FirebaseAuthPlatform auth, String uid)
    : super(
        auth,
        _MultiFactor(auth),
        auth_platform.InternalUserDetails(
          userInfo: auth_platform.InternalUserInfo(uid: uid, isAnonymous: false, isEmailVerified: true),
          providerData: const <Map<Object?, Object?>?>[],
        ),
      );
}

class _PlatformAuth extends auth_platform.FirebaseAuthPlatform {
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
  auth_platform.UserPlatform? get currentUser => uid == null ? null : _PlatformUser(this, uid!);

  @override
  Future<void> signOut() async {
    signOutCalls++;
    uid = null;
  }
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String? get email => 'user@example.com';
}

class _Auth extends Fake implements FirebaseAuth {
  User? user;
  int signOutCalls = 0;
  @override
  User? get currentUser => user;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    user = null;
  }
}

class _Google extends Fake implements GoogleSignIn {
  int initializeCalls = 0;
  int authenticateCalls = 0;
  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {
    initializeCalls++;
  }

  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) async {
    authenticateCalls++;
    throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
  }

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

class _GatedTasteStore extends TasteSignalStore {
  _GatedTasteStore(super.settings);
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> clear({bool allowReseed = false}) async {
    started.complete();
    await release.future;
    await super.clear(allowReseed: allowReseed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const appleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
  final startup = Completer<bool>();
  final platformAuth = _PlatformAuth();
  late auth_platform.FirebaseAuthPlatform previousAuth;
  late SettingsLocalDataSource settings;
  late FakeAppAnalytics analytics;
  int appleCalls = 0;

  Future<void> initializeFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: const FirebaseOptions(apiKey: 'test', appId: 'test', messagingSenderId: 'test', projectId: 'test'),
    );
  }

  setUpAll(() {
    TestFirebaseCoreHostApi.setUp(_Core());
    previousAuth = auth_platform.FirebaseAuthPlatform.instance;
    auth_platform.FirebaseAuthPlatform.instance = platformAuth;
    FirebaseInit.setFuture(startup.future);
  });

  tearDownAll(() => auth_platform.FirebaseAuthPlatform.instance = previousAuth);

  setUp(() async {
    await getIt.reset();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<FirestoreClient>(FakeFirestoreClient());
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    app_state.prismUser = profileUser();
    platformAuth
      ..uid = null
      ..signOutCalls = 0;
    appleCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(appleChannel, (_) async {
      appleCalls++;
      throw PlatformException(code: 'authorization-error/canceled');
    });
  });

  tearDown(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    AnalyticsRuntime.reset();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(appleChannel, null);
  });

  test('null Firebase auth still clears local identity and personalization', () async {
    final sessionLocal = SessionLocalDataSource(InMemoryLocalStore());
    await sessionLocal.writeCurrentUser(profileUser());
    getIt.registerSingleton<SessionRepository>(SessionRepositoryImpl(sessionLocal));
    final taste = TasteSignalStore(settings);
    getIt.registerSingleton<TasteSignalStore>(taste);
    await taste.record(
      TasteSignal(action: TasteAction.favourite, at: DateTime.now().toUtc(), terms: const ['private']),
    );
    final auth = GoogleAuth(googleSignIn: _Google(), messaging: _Messaging(), firebaseReady: () async => false);

    expect(await auth.signOutGoogle(), isTrue);
    expect(app_state.prismUser.id, isEmpty);
    expect(app_state.prismUser.loggedIn, isFalse);
    expect(taste.read(), isEmpty);
    expect(analytics.userIds, <String?>[null]);
    final persisted = sessionLocal.readCurrentUser();
    expect(persisted.id, isEmpty);
    expect(persisted.loggedIn, isFalse);
  });

  test('late Firebase initialization during sign-out also clears the restored Firebase session', () async {
    expect(Firebase.apps, isEmpty);
    final taste = _GatedTasteStore(settings);
    getIt.registerSingleton<TasteSignalStore>(taste);
    final auth = GoogleAuth(googleSignIn: _Google(), messaging: _Messaging(), firebaseReady: () async => false);
    final pending = auth.signOutGoogle();
    await taste.started.future;
    await initializeFirebase();
    platformAuth.uid = 'u1';
    taste.release.complete();

    expect(await pending, isTrue);
    expect(app_state.prismUser.id, isEmpty);
    expect(platformAuth.signOutCalls, 1);
    expect(FirebaseAuth.instance.currentUser, isNull);
  });

  test('Google auth reserves local ownership before its first await', () async {
    final firebase = _Auth();
    final google = _Google();
    final auth = GoogleAuth(auth: firebase, googleSignIn: google);
    final pending = auth.signInWithGoogle();
    final rejected = expectLater(pending, throwsStateError);
    final replacement = profileUser(id: 'replacement');
    app_state.prismUser = replacement;
    firebase.user = _User('replacement');

    await rejected;
    expect(google.authenticateCalls, 0);
    expect(app_state.prismUser, same(replacement));
  });

  test('Apple auth reserves local ownership before its first await', () async {
    final firebase = _Auth();
    final pending = AppleAuth(auth: firebase).signInWithApple();
    final rejected = expectLater(pending, throwsStateError);
    final replacement = profileUser(id: 'replacement');
    app_state.prismUser = replacement;
    firebase.user = _User('replacement');

    await rejected;
    expect(appleCalls, 0);
    expect(app_state.prismUser, same(replacement));
  });

  test('sign-out cannot adopt a replacement account during its first await', () async {
    final firebase = _Auth()..user = _User('u1');
    final auth = GoogleAuth(auth: firebase, googleSignIn: _Google(), messaging: _Messaging());
    final pending = auth.signOutGoogle();
    final replacement = profileUser(id: 'replacement');
    app_state.prismUser = replacement;
    firebase.user = _User('replacement');

    expect(await pending, isFalse);
    expect(firebase.signOutCalls, 0);
    expect(firebase.currentUser?.uid, 'replacement');
    expect(app_state.prismUser, same(replacement));
  });

  test('a newer operation invalidates an older Google readiness wait', () async {
    await initializeFirebase();
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final ready = Completer<bool>();
    final google = _Google();
    final pending = GoogleAuth(googleSignIn: google, firebaseReady: () => ready.future).signInWithGoogle();
    final rejected = expectLater(pending, throwsStateError);
    expect(await GoogleAuth(auth: _Auth(), googleSignIn: _Google(), messaging: _Messaging()).signOutGoogle(), isTrue);
    ready.complete(true);

    await rejected;
    expect(google.authenticateCalls, 0);
  });

  test('a newer operation invalidates an older Apple readiness wait', () async {
    await initializeFirebase();
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final ready = Completer<bool>();
    final pending = AppleAuth(firebaseReady: () => ready.future).signInWithApple();
    final rejected = expectLater(pending, throwsStateError);
    expect(await GoogleAuth(auth: _Auth(), googleSignIn: _Google(), messaging: _Messaging()).signOutGoogle(), isTrue);
    ready.complete(true);

    await rejected;
    expect(appleCalls, 0);
  });

  test('Google waits without opening its provider and retries the same instance after unavailable Firebase', () async {
    await initializeFirebase();
    final google = _Google();
    final ready = Completer<bool>();
    var retry = false;
    final auth = GoogleAuth(googleSignIn: google, firebaseReady: () => retry ? Future.value(true) : ready.future);
    final pending = auth.signInWithGoogle();
    final rejected = expectLater(pending, throwsA(isA<FirebaseUnavailableException>()));
    await pumpEventQueue();
    expect(google.initializeCalls, 0);
    expect(google.authenticateCalls, 0);
    ready.complete(false);
    await rejected;
    retry = true;

    expect(await auth.signInWithGoogle(), SignInOutcome.cancelled);
    expect(google.authenticateCalls, 1);
  });

  test('Apple waits without opening its provider and retries the same instance after unavailable Firebase', () async {
    await initializeFirebase();
    final ready = Completer<bool>();
    var retry = false;
    final auth = AppleAuth(firebaseReady: () => retry ? Future.value(true) : ready.future);
    final pending = auth.signInWithApple();
    final rejected = expectLater(pending, throwsA(isA<FirebaseUnavailableException>()));
    await pumpEventQueue();
    expect(appleCalls, 0);
    ready.complete(false);
    await rejected;
    retry = true;

    expect(await auth.signInWithApple(), SignInOutcome.cancelled);
    expect(appleCalls, 1);
  });

  test('Google binds the restored Firebase UID only after readiness', () async {
    await initializeFirebase();
    final ready = Completer<bool>();
    final google = _Google();
    final pending = GoogleAuth(googleSignIn: google, firebaseReady: () => ready.future).signInWithGoogle();
    await pumpEventQueue();
    expect(google.authenticateCalls, 0);
    platformAuth.uid = 'restored';
    ready.complete(true);

    expect(await pending, SignInOutcome.cancelled);
    expect(google.authenticateCalls, 1);
    expect(FirebaseAuth.instance.currentUser?.uid, 'restored');
  });

  test('Apple binds the restored Firebase UID only after readiness', () async {
    await initializeFirebase();
    final ready = Completer<bool>();
    final pending = AppleAuth(firebaseReady: () => ready.future).signInWithApple();
    await pumpEventQueue();
    expect(appleCalls, 0);
    platformAuth.uid = 'restored';
    ready.complete(true);

    expect(await pending, SignInOutcome.cancelled);
    expect(appleCalls, 1);
    expect(FirebaseAuth.instance.currentUser?.uid, 'restored');
  });

  test('unavailable Firebase blocks both reauthentication providers', () async {
    final google = _Google();
    await expectLater(
      GoogleAuth(googleSignIn: google, firebaseReady: () async => false).reauthenticateCurrentUser(),
      throwsA(isA<FirebaseUnavailableException>()),
    );
    await expectLater(
      AppleAuth(firebaseReady: () async => false).reauthenticateCurrentUser(),
      throwsA(isA<FirebaseUnavailableException>()),
    );
    expect(google.initializeCalls, 0);
    expect(google.authenticateCalls, 0);
    expect(appleCalls, 0);
  });

  testWidgets('three-second Firebase timeout permits retry when initialization later completes', (tester) async {
    final google = _Google();
    final auth = GoogleAuth(googleSignIn: google, firebaseReady: FirebaseInit.waitUntilReady);
    final apple = AppleAuth(firebaseReady: FirebaseInit.waitUntilReady);
    Object? failure;
    Object? appleFailure;
    auth.signInWithGoogle().then<void>((_) {}, onError: (Object error) => failure = error);
    apple.signInWithApple().then<void>((_) {}, onError: (Object error) => appleFailure = error);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2999));
    expect(failure, isNull);
    expect(appleFailure, isNull);
    expect(google.authenticateCalls, 0);
    expect(appleCalls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(failure, isA<FirebaseUnavailableException>());
    expect(appleFailure, isA<FirebaseUnavailableException>());
    expect(google.authenticateCalls, 0);
    expect(appleCalls, 0);

    await tester.runAsync(() async {
      startup.complete(true);
      await FirebaseInit.readyFuture;
      expect(await auth.signInWithGoogle(), SignInOutcome.cancelled);
      expect(google.authenticateCalls, 1);
      expect(await apple.signInWithApple(), SignInOutcome.cancelled);
      expect(appleCalls, 1);
    });
  });
}
