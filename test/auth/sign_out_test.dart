import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';
import '../support/profile_user_fixture.dart';

/// Every call the sign-out path makes, in order.
final List<String> _log = <String>[];

class _LoggingFirestore extends FakeFirestoreClient {
  bool failReads = false;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    if (failReads) return Future<T?>.error(StateError('offline'));
    return super.getById(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) {
    _log.add('firestore.update $collection/$id $data');
    return super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }
}

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
  @override
  String? get email => 'user@example.com';
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
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    _log.add('auth.signIn');
    return _FakeUserCredential();
  }

  @override
  Future<void> signOut() async => _log.add('auth.signOut');
}

// ignore: avoid_implementing_value_types
class _FakeAccount extends Fake implements GoogleSignInAccount {
  @override
  GoogleSignInAuthentication get authentication => const GoogleSignInAuthentication(idToken: 'id-token');
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}

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

void main() {
  late _LoggingFirestore firestore;
  late SettingsLocalDataSource settings;
  late GoogleAuth auth;

  setUp(() async {
    _log.clear();
    await getIt.reset();
    firestore = _LoggingFirestore();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt
      ..registerSingleton<FirestoreClient>(firestore)
      ..registerSingleton<TasteSignalStore>(TasteSignalStore(settings))
      ..registerSingleton<FeedImpressionStore>(FeedImpressionStore(settings));
    auth = GoogleAuth(auth: _FakeAuth(), googleSignIn: _FakeGoogleSignIn(), messaging: _FakeMessaging());
  });

  tearDown(() => getIt.reset());

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

  test('a failed logged-out write does not block sign-out', () async {
    app_state.prismUser = profileUser();
    getIt
      ..unregister<FirestoreClient>()
      ..registerSingleton<FirestoreClient>(_ThrowingFirestore());

    expect(await auth.signOutGoogle(), isTrue);
    expect(_log, contains('auth.signOut'));
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

  test('a sign-in that fails after Firebase accepted the credential signs out again', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    firestore.failReads = true;

    await expectLater(auth.signInWithGoogle(), throwsStateError);

    expect(_log, <String>['auth.signIn', 'auth.signOut']);
  });
}

class _ThrowingFirestore extends Fake implements FirestoreClient {
  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) =>
      Future<void>.error(StateError('permission-denied'));
}
