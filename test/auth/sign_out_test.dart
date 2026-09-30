import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_error_reporter.dart';
import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';
import '../support/profile_user_fixture.dart';

/// Every call the sign-out path makes, in order.
final List<String> _log = <String>[];

class _LoggingFirestore extends FakeFirestoreClient {
  bool failReads = false;
  Object? readError;
  Completer<void>? loggedOutWriteStarted;
  Completer<void>? loggedOutWriteGate;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    if (readError != null) return Future<T?>.error(readError!);
    if (failReads) return Future<T?>.error(StateError('offline'));
    return super.getById(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    _log.add('firestore.update $collection/$id $data');
    if (data['loggedIn'] == false) {
      loggedOutWriteStarted?.complete();
      await loggedOutWriteGate?.future;
    }
    await super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser({this.uid = 'u1', this.email = 'user@example.com'});

  @override
  final String uid;
  @override
  final String? email;
  @override
  String? get displayName => 'User';
  @override
  String? get photoURL => null;
}

class _FakeUserCredential extends Fake implements UserCredential {
  @override
  User? get user => _FakeUser();
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth({this.user, this.signOutError});

  User? user;
  final Object? signOutError;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    _log.add('auth.signIn');
    user = _FakeUser();
    return _FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    _log.add('auth.signOut');
    if (signOutError != null) throw signOutError!;
    user = null;
  }
}

// ignore: avoid_implementing_value_types
class _FakeAccount extends Fake implements GoogleSignInAccount {
  @override
  GoogleSignInAuthentication get authentication => const GoogleSignInAuthentication(idToken: 'id-token');
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  _FakeGoogleSignIn({this.initializeError});

  final Object? initializeError;

  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {
    if (initializeError != null) throw initializeError!;
  }

  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) async => _FakeAccount();

  @override
  Future<void> signOut() async {}
}

class _FakeMessaging extends Fake implements FirebaseMessaging {
  @override
  Future<String?> getAPNSToken() async => 'apns';

  @override
  Future<void> unsubscribeFromTopic(String topic) async => _log.add('fcm.unsubscribe $topic');
}

class _ThrowingAnalytics extends FakeAppAnalytics {
  _ThrowingAnalytics({this.failure, this.failIdentity = false});

  final Object? failure;
  final bool failIdentity;
  int userIdAttempts = 0;
  int propertyAttempts = 0;

  @override
  Future<void> track(AnalyticsEvent event) => Future<void>.error(failure ?? StateError('analytics unavailable'));

  @override
  Future<void> setUserId(String? userId) {
    userIdAttempts++;
    if (failIdentity) return Future<void>.error(StateError('analytics unavailable'));
    return super.setUserId(userId);
  }

  @override
  Future<void> setUserProperty({required String name, String? value}) {
    propertyAttempts++;
    if (failIdentity) return Future<void>.error(StateError('analytics unavailable'));
    return super.setUserProperty(name: name, value: value);
  }
}

class _ThrowingErrorReporter extends FakeErrorReporter {
  @override
  Future<void> clearUser() => Future<void>.error(StateError('monitoring unavailable'));
}

class _FailingTasteSignalStore extends TasteSignalStore {
  _FailingTasteSignalStore(super.settingsLocal);

  @override
  Future<void> clear({bool allowReseed = false}) => Future<void>.error(StateError('disk full'));
}

void main() {
  late _LoggingFirestore firestore;
  late SettingsLocalDataSource settings;
  late GoogleAuth auth;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _log.clear();
    AnalyticsRuntime.reset();
    await getIt.reset();
    firestore = _LoggingFirestore();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt
      ..registerSingleton<FirestoreClient>(firestore)
      ..registerSingleton<TasteSignalStore>(TasteSignalStore(settings))
      ..registerSingleton<FeedImpressionStore>(FeedImpressionStore(settings));
    auth = GoogleAuth(auth: _FakeAuth(), googleSignIn: _FakeGoogleSignIn(), messaging: _FakeMessaging());
  });

  tearDown(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    AnalyticsRuntime.reset();
    MonitoringRuntime.reset();
    await getIt.reset();
  });

  test('marks the user logged out and drops their topics before Firebase sign-out', () async {
    app_state.prismUser = profileUser()..following = <String>['creator@example.com'];

    await auth.signOutGoogle();

    final int signOutAt = _log.indexOf('auth.signOut');
    expect(signOutAt, isNonNegative);
    for (final String call in <String>[
      'firestore.update usersv2/u1 {loggedIn: false}',
      'fcm.unsubscribe u_u1',
      'fcm.unsubscribe user',
      'fcm.unsubscribe creator_posts',
    ]) {
      expect(_log.indexOf(call), allOf(isNonNegative, lessThan(signOutAt)), reason: call);
    }
    expect(app_state.prismUser.id, isEmpty);
  });

  test('waits for the logged-out server write to finish before Firebase sign-out', () async {
    app_state.prismUser = profileUser();
    firestore.loggedOutWriteStarted = Completer<void>();
    firestore.loggedOutWriteGate = Completer<void>();

    final Future<bool> signOut = auth.signOutGoogle();
    await firestore.loggedOutWriteStarted!.future;
    expect(_log, isNot(contains('auth.signOut')));

    firestore.loggedOutWriteGate!.complete();
    expect(await signOut, isTrue);
    expect(_log.indexOf('auth.signOut'), greaterThan(_log.indexOf('firestore.update usersv2/u1 {loggedIn: false}')));
  });

  test('a failed logged-out write does not block sign-out', () async {
    app_state.prismUser = profileUser();
    getIt
      ..unregister<FirestoreClient>()
      ..registerSingleton<FirestoreClient>(_ThrowingFirestore());

    expect(await auth.signOutGoogle(), isTrue);
    expect(_log, contains('auth.signOut'));
  });

  test('an already deleted Firebase account still completes local sign-out', () async {
    app_state.prismUser = profileUser();
    final TasteSignalStore taste = getIt<TasteSignalStore>();
    final FeedImpressionStore impressions = getIt<FeedImpressionStore>();
    final DateTime now = DateTime.now().toUtc();
    await taste.record(TasteSignal(action: TasteAction.favourite, at: now, terms: const <String>['private']));
    await impressions.recordShown(<String>['private'], now);
    getIt
      ..unregister<FirestoreClient>()
      ..registerSingleton<FirestoreClient>(_ThrowingFirestore());

    expect(await auth.signOutGoogle(), isTrue);
    expect(_log, contains('auth.signOut'));
    expect(taste.read(), isEmpty);
    expect(impressions.recentShows(now), isEmpty);
  });

  test('a Google SDK initialization failure does not block Firebase sign-out', () async {
    app_state.prismUser = profileUser();
    auth = GoogleAuth(
      auth: _FakeAuth(),
      googleSignIn: _FakeGoogleSignIn(initializeError: StateError('offline')),
    );

    expect(await auth.signOutGoogle(), isTrue);
    expect(_log, contains('auth.signOut'));
  });

  test('sign-out cleans up the authenticated uid when app state is stale', () async {
    app_state.prismUser = profileUser(id: 'stale')..email = 'stale@example.com';
    auth = GoogleAuth(
      auth: _FakeAuth(user: _FakeUser(uid: 'current', email: null)),
      googleSignIn: _FakeGoogleSignIn(),
      messaging: _FakeMessaging(),
    );
    firestore.docs['usersv2'] = <String, Map<String, dynamic>>{
      'current': <String, dynamic>{
        'email': 'current@example.com',
        'following': <String>['creator@example.com'],
      },
    };

    await auth.signOutGoogle();

    expect(_log, contains('firestore.update usersv2/current {loggedIn: false}'));
    expect(_log, isNot(contains('firestore.update usersv2/stale {loggedIn: false}')));
    expect(_log, contains('fcm.unsubscribe u_current'));
    expect(_log, contains('fcm.unsubscribe current'));
    expect(_log, contains('fcm.unsubscribe creator_posts'));
    expect(_log, isNot(contains('fcm.unsubscribe stale')));
  });

  test('reports Firebase sign-out failure after completing local cleanup', () async {
    app_state.prismUser = profileUser();
    auth = GoogleAuth(
      auth: _FakeAuth(user: _FakeUser(), signOutError: StateError('offline')),
      googleSignIn: _FakeGoogleSignIn(),
      messaging: _FakeMessaging(),
    );

    expect(await auth.signOutGoogle(), isFalse);
    expect(_log, contains('auth.signOut'));
    expect(app_state.prismUser.id, isEmpty);
  });

  test('clears on-device personalization so the next user starts fresh', () async {
    app_state.prismUser = profileUser();
    final TasteSignalStore taste = getIt<TasteSignalStore>();
    final FeedImpressionStore impressions = getIt<FeedImpressionStore>();
    final DateTime now = DateTime.now().toUtc();
    await taste.record(TasteSignal(action: TasteAction.favourite, at: now, terms: const <String>['anime']));
    await taste.markSeeded();
    await impressions.recordShown(<String>['seen'], now);
    await impressions.hide('hidden', now);

    await auth.signOutGoogle();

    expect(taste.read(), isEmpty);
    expect(taste.isSeeded, isFalse, reason: 'the next user seeds from their own favourites');
    expect(impressions.recentShows(now), isEmpty);
  });

  test('clears feed impressions even when the taste store is not registered', () async {
    app_state.prismUser = profileUser();
    final FeedImpressionStore impressions = getIt<FeedImpressionStore>();
    final DateTime now = DateTime.now().toUtc();
    await impressions.recordShown(<String>['seen'], now);
    await getIt.unregister<TasteSignalStore>();

    await auth.signOutGoogle();

    expect(impressions.recentShows(now), isEmpty);
  });

  test('clears feed impressions when taste-store cleanup throws', () async {
    app_state.prismUser = profileUser();
    final FeedImpressionStore impressions = getIt<FeedImpressionStore>();
    final DateTime now = DateTime.now().toUtc();
    await impressions.recordShown(<String>['seen'], now);
    await getIt.unregister<TasteSignalStore>();
    getIt.registerSingleton<TasteSignalStore>(_FailingTasteSignalStore(settings));

    await auth.signOutGoogle();

    expect(impressions.recentShows(now), isEmpty);
  });

  test('analytics and monitoring cleanup errors do not interrupt sign-out cleanup', () async {
    app_state.prismUser = profileUser();
    final _ThrowingAnalytics analytics = _ThrowingAnalytics(failIdentity: true);
    AnalyticsRuntime.instance = analytics;
    MonitoringRuntime.reporter = _ThrowingErrorReporter();

    expect(await auth.signOutGoogle(), isTrue);

    expect(_log, contains('auth.signOut'));
    expect(app_state.prismUser.id, isEmpty);
    expect(analytics.userIdAttempts, 1);
    expect(analytics.propertyAttempts, 2);
  });

  test('a sign-in that fails after Firebase accepted the credential signs out again', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    firestore.failReads = true;
    AnalyticsRuntime.instance = _ThrowingAnalytics(failure: StateError('analytics unavailable'));

    await expectLater(
      auth.signInWithGoogle(),
      throwsA(isA<StateError>().having((StateError error) => error.message, 'message', 'offline')),
    );

    expect(_log.first, 'auth.signIn');
    expect(_log.last, 'auth.signOut');
    expect(_log, contains('firestore.update usersv2/u1 {loggedIn: false}'));
  });

  test('a cancellation-classified error after credential acceptance still rolls Firebase back', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    firestore.readError = const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);

    expect(await auth.signInWithGoogle(), SignInOutcome.cancelled);

    expect(_log.last, 'auth.signOut');
    expect(_log, contains('firestore.update usersv2/u1 {loggedIn: false}'));
  });
}

class _ThrowingFirestore extends Fake implements FirestoreClient {
  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) =>
      Future<void>.error(StateError('permission-denied'));
}
