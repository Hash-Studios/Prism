import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/account/username_service.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/session_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/data/repositories/session_repository_impl.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';
import '../support/profile_user_fixture.dart';

class _DelayedWriteFirestore extends FakeFirestoreClient {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> writeGate = Completer<void>();
  bool _blockedOnce = false;
  final List<String> readTags = <String>[];
  Completer<void>? readGate;
  final Completer<void> readStarted = Completer<void>();

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    readTags.add(sourceTag);
    if (!readStarted.isCompleted) readStarted.complete();
    await readGate?.future;
    return super.getById(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }

  Future<void> _waitForWrite() async {
    if (!_blockedOnce) {
      _blockedOnce = true;
      writeStarted.complete();
      await writeGate.future;
    }
  }

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    await _waitForWrite();
    await super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    await _waitForWrite();
    await super.setDoc(collection, id, data, merge: merge, sourceTag: sourceTag);
  }
}

class _User extends Fake implements User {
  _User({this.uid = 'u1', this.displayName = 'User', this.photoURL});

  @override
  final String uid;
  Completer<void>? nameGate;
  final nameStarted = Completer<void>();
  @override
  String? get email => 'user@example.com';
  @override
  String? displayName;
  @override
  String? photoURL;
  @override
  bool get isAnonymous => false;
  @override
  Future<void> updateDisplayName(String? displayName) async {
    nameStarted.complete();
    await nameGate?.future;
    this.displayName = displayName;
  }

  @override
  Future<void> updatePhotoURL(String? photoURL) async => this.photoURL = photoURL;
}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);

  @override
  final User user;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth([_User? user]) : user = user ?? _User();

  _User? user;
  final List<String> calls = <String>[];

  @override
  User? get currentUser => user;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async => _Credential(user!);
  @override
  Future<void> signOut() async {
    calls.add('auth.signOut');
    user = null;
  }
}

// ignore: avoid_implementing_value_types
class _Account extends Fake implements GoogleSignInAccount {
  _Account({this.displayName = 'User', this.photoUrl});

  @override
  final String? displayName;
  @override
  final String? photoUrl;
  @override
  GoogleSignInAuthentication get authentication => const GoogleSignInAuthentication(idToken: 'id-token');
}

class _GoogleSignIn extends Fake implements GoogleSignIn {
  _GoogleSignIn([_Account? account]) : account = account ?? _Account();

  final _Account account;
  Completer<GoogleSignInAccount>? authenticationGate;
  final authenticationStarted = Completer<void>();

  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}
  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) async {
    authenticationStarted.complete();
    return authenticationGate?.future ?? account;
  }

  @override
  Future<void> signOut() async {}
}

class _Messaging extends Fake implements FirebaseMessaging {
  final List<String> topics = <String>[];
  @override
  Future<String?> getAPNSToken() async => 'apns';
  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
  @override
  Future<void> subscribeToTopic(String topic) async => topics.add(topic);
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  @override
  Future<void> deleteToken() async {}
}

class _DelayedAnalytics extends FakeAppAnalytics {
  final started = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<void> setUserId(String? userId) async {
    await super.setUserId(userId);
    started.complete();
    await gate.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel purchasesChannel = MethodChannel('purchases_flutter');
  late _DelayedWriteFirestore firestore;
  late bool delayCustomerInfo;
  late Completer<void> customerInfoStarted;
  late Completer<Map<String, Object?>> customerInfoGate;

  setUp(() async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    await getIt.reset();
    firestore = _DelayedWriteFirestore();
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{'u1': profileUser().toJson()};
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    UsernameService.instance = UsernameService(
      request: (data) async => <String, Object?>{'username': data['username']},
    );
    delayCustomerInfo = false;
    customerInfoStarted = Completer<void>();
    customerInfoGate = Completer<Map<String, Object?>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(purchasesChannel, (
      MethodCall call,
    ) async {
      if (call.method == 'logOut') return _customerInfo();
      if (call.method != 'getCustomerInfo') return null;
      customerInfoStarted.complete();
      return delayCustomerInfo ? customerInfoGate.future : _customerInfo();
    });
  });

  tearDown(() async {
    if (!firestore.writeGate.isCompleted) firestore.writeGate.complete();
    if (!customerInfoGate.isCompleted) customerInfoGate.complete(_customerInfo());
    await waitForSignInBootstraps();
    await FcmTokenService.instance.cancelAndWait();
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    await getIt.reset();
    AnalyticsRuntime.reset();
    UsernameService.instance = UsernameService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(purchasesChannel, null);
  });

  test('existing-user loggedIn write finishes before sign-in can complete', () async {
    final GoogleAuth auth = GoogleAuth(auth: _Auth(), googleSignIn: _GoogleSignIn(), messaging: _Messaging());
    bool completed = false;
    final Future<Object?> signIn = auth.signInWithGoogle().then((value) {
      completed = true;
      return value;
    });

    await firestore.writeStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    firestore.writeGate.complete();
    await signIn;
    expect(completed, isTrue);
  });

  test('Google sign-in survives a same-account persisted session reload during its profile write', () async {
    final repository = SessionRepositoryImpl(SessionLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<SessionRepository>(repository);
    final firebase = _Auth();
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    final pending = GoogleAuth(
      auth: firebase,
      googleSignIn: _GoogleSignIn(),
      messaging: _Messaging(),
    ).signInWithGoogle();
    await firestore.writeStarted.future;
    await app_state.persistPrismUser();
    final published = repository.currentUser;
    await repository.getSession();
    expect(repository.currentUser, isNot(same(published)));
    expect(repository.currentUser.id, 'u1');
    expect(repository.currentUser.loggedIn, isTrue);
    firestore.writeGate.complete();

    expect(await pending, SignInOutcome.signedIn);
    expect(app_state.prismUser.id, 'u1');
    expect(app_state.prismUser.loggedIn, isTrue);
    expect(firebase.currentUser?.uid, 'u1');
    expect(analytics.userIds, <String>['u1']);
    expect(analytics.events.last.toWireParameters()['result'], 'success');
  });

  test('initial naming applies to the reloaded same-account profile and survives persistence', () async {
    firestore.docs.clear();
    firestore.writeGate.complete();
    final local = SessionLocalDataSource(InMemoryLocalStore());
    final repository = SessionRepositoryImpl(local);
    getIt.registerSingleton<SessionRepository>(repository);
    final started = Completer<void>();
    final claimed = Completer<Object?>();
    UsernameService.instance = UsernameService(
      request: (_) {
        started.complete();
        return claimed.future;
      },
    );
    final pending = GoogleAuth(
      auth: _Auth(),
      googleSignIn: _GoogleSignIn(),
      messaging: _Messaging(),
    ).signInWithGoogle();
    await started.future;
    await app_state.persistPrismUser();
    await repository.getSession();
    claimed.complete(<String, Object?>{'username': 'ServerWinner'});

    expect(await pending, SignInOutcome.signedIn);
    expect(app_state.prismUser.username, 'ServerWinner');
    expect(local.readCurrentUser().username, 'ServerWinner');
  });

  test('same-account logout during a profile write still stops sign-in', () async {
    final firebase = _Auth();
    final pending = GoogleAuth(
      auth: firebase,
      googleSignIn: _GoogleSignIn(),
      messaging: _Messaging(),
    ).signInWithGoogle();
    final rejected = expectLater(pending, throwsStateError);
    await firestore.writeStarted.future;
    app_state.prismUser = profileUser(loggedIn: false);
    firestore.writeGate.complete();
    await rejected;
    expect(app_state.prismUser.id, 'u1');
    expect(app_state.prismUser.loggedIn, isFalse);
    expect(firebase.currentUser?.uid, 'u1');
  });

  test('sign-in reads the user document once for coins, not twice', () async {
    final GoogleAuth auth = GoogleAuth(auth: _Auth(), googleSignIn: _GoogleSignIn(), messaging: _Messaging());
    final Future<Object?> signIn = auth.signInWithGoogle();
    await firestore.writeStarted.future;
    firestore.writeGate.complete();
    await signIn;
    await waitForSignInBootstraps();

    expect(firestore.readTags.where((String tag) => tag.startsWith('coins.')), contains('coins.bootstrap'));
    expect(firestore.readTags, isNot(contains('coins.refresh_balance')));
  });

  test('new-user document create finishes before sign-in can complete', () async {
    firestore.docs.clear();
    final GoogleAuth auth = GoogleAuth(auth: _Auth(), googleSignIn: _GoogleSignIn(), messaging: _Messaging());
    bool completed = false;
    final Future<Object?> signIn = auth.signInWithGoogle().then((value) {
      completed = true;
      return value;
    });

    await firestore.writeStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    firestore.writeGate.complete();
    await signIn;
    expect(completed, isTrue);
    final Map<String, dynamic> created = firestore.docs[FirebaseCollections.usersV2]!['u1']!;
    expect(created['username'], '');
    expect(created['usernameCandidate'], 'User');
    expect(app_state.prismUser.username, 'User');
  });

  test('initial naming waits for the server winner and does not publish a provisional candidate', () async {
    firestore.docs.clear();
    firestore.writeGate.complete();
    final Completer<Object?> reservation = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    UsernameService.instance = UsernameService(
      request: (data) {
        expect(data, <String, Object?>{'username': 'User', 'initial': true});
        started.complete();
        return reservation.future;
      },
    );
    bool completed = false;
    final Future<void> signIn = completeSignIn(
      user: _User(),
      displayName: 'User',
      email: 'wrong@example.com',
      photoUrl: '',
      sourceTagPrefix: 'test',
      messaging: _Messaging(),
    ).then((_) => completed = true);
    await started.future;
    expect(completed, isFalse);
    expect(app_state.prismUser.username, isEmpty);
    expect(firestore.docs[FirebaseCollections.usersV2]!['u1']!['email'], 'user@example.com');
    reservation.complete(<String, Object?>{'username': 'User_u1'});
    await signIn;
    expect(app_state.prismUser.username, 'User_u1');
  });

  test('failed initial claim remains unnamed and the next sign-in can retry', () async {
    firestore.docs.clear();
    firestore.writeGate.complete();
    UsernameService.instance = UsernameService(request: (_) async => throw StateError('offline'));
    Future<void> signIn() => completeSignIn(
      user: _User(),
      displayName: 'User',
      email: 'user@example.com',
      photoUrl: '',
      sourceTagPrefix: 'test',
      messaging: _Messaging(),
    );
    await expectLater(signIn(), throwsStateError);
    expect(app_state.prismUser.username, isEmpty);
    expect(app_state.prismUser.loggedIn, isFalse);
    UsernameService.instance = UsernameService(request: (_) async => <String, Object?>{'username': 'User_u1'});
    await signIn();
    expect(app_state.prismUser.username, 'User_u1');
  });

  test('an initial claim completed after account switch cannot mutate or persist the new session', () async {
    firestore.docs.clear();
    firestore.writeGate.complete();
    final Completer<Object?> reservation = Completer<Object?>();
    final Completer<void> started = Completer<void>();
    UsernameService.instance = UsernameService(
      request: (_) {
        started.complete();
        return reservation.future;
      },
    );
    final Future<void> signIn = completeSignIn(
      user: _User(),
      displayName: 'User',
      email: 'user@example.com',
      photoUrl: '',
      sourceTagPrefix: 'test',
      messaging: _Messaging(),
    );
    final Future<void> rejected = expectLater(signIn, throwsStateError);
    await started.future;
    final original = app_state.prismUser;
    app_state.prismUser = profileUser(id: 'other', username: 'Other');
    reservation.complete(<String, Object?>{'username': 'User_u1'});
    await rejected;
    expect(original.username, isEmpty);
    expect(app_state.prismUser.username, 'Other');
    expect(app_state.prismUser.loggedIn, isTrue);
  });

  for (final bool existing in <bool>[false, true]) {
    test('Google delayed ${existing ? 'update' : 'create'} cannot roll back or initialize a replacement', () async {
      if (!existing) firestore.docs.clear();
      if (existing) firestore.docs[FirebaseCollections.usersV2]!['u1']!['username'] = '';
      final analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      final claims = <Object?>[];
      UsernameService.instance = UsernameService(
        request: (data) async {
          claims.add(data);
          return <String, Object?>{'username': 'Wrong'};
        },
      );
      final firebase = _Auth();
      final pending = GoogleAuth(
        auth: firebase,
        googleSignIn: _GoogleSignIn(),
        messaging: _Messaging(),
      ).signInWithGoogle();
      final rejected = expectLater(pending, throwsStateError);
      await firestore.writeStarted.future;
      final replacement = profileUser(id: 'other');
      app_state.prismUser = replacement;
      firebase.user = _User(uid: 'other');
      firestore.writeGate.complete();
      await rejected;
      expect(firebase.calls, isEmpty);
      expect(firebase.currentUser?.uid, 'other');
      expect(app_state.prismUser, same(replacement));
      expect(claims, isEmpty);
      expect(customerInfoStarted.isCompleted, isFalse);
      expect(analytics.events, isEmpty);
    });

    test('delayed ${existing ? 'update' : 'create'} cannot name or bootstrap a replacement session', () async {
      if (!existing) firestore.docs.clear();
      if (existing) firestore.docs[FirebaseCollections.usersV2]!['u1']!['username'] = '';
      final List<Object?> claims = <Object?>[];
      UsernameService.instance = UsernameService(
        request: (data) async {
          claims.add(data);
          return <String, Object?>{'username': 'Wrong'};
        },
      );
      final Future<void> signIn = completeSignIn(
        user: _User(),
        displayName: 'User',
        email: 'user@example.com',
        photoUrl: '',
        sourceTagPrefix: 'test',
        messaging: _Messaging(),
      );
      final Future<void> rejected = expectLater(signIn, throwsStateError);
      await firestore.writeStarted.future;
      final replacement = profileUser(id: 'other');
      app_state.prismUser = replacement;
      firestore.writeGate.complete();
      await rejected;
      await waitForSignInBootstraps();
      expect(claims, isEmpty);
      expect(app_state.prismUser, same(replacement));
      expect(replacement.username, isEmpty);
      expect(customerInfoStarted.isCompleted, isFalse);
      expect(firestore.readTags.where((tag) => tag.startsWith('coins.')), isEmpty);
    });
  }

  test('Google profile await stops photo writes and success analytics after a Firebase-only switch', () async {
    final analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    firestore.writeGate.complete();
    final user = _User(displayName: 'Old', photoURL: 'old')..nameGate = Completer<void>();
    final firebase = _Auth(user);
    final pending = GoogleAuth(
      auth: firebase,
      googleSignIn: _GoogleSignIn(_Account(displayName: 'New', photoUrl: 'new')),
      messaging: _Messaging(),
    ).signInWithGoogle();
    final rejected = expectLater(pending, throwsStateError);
    await user.nameStarted.future;
    firebase.user = _User(uid: 'other');
    user.nameGate!.complete();
    await rejected;
    expect(user.photoURL, 'old');
    expect(firebase.calls, isEmpty);
    expect(firebase.currentUser?.uid, 'other');
    expect(analytics.events, isEmpty);
  });

  test('a new Google attempt invalidates an old write even before the new credential is accepted', () async {
    final firebase = _Auth();
    final oldPending = GoogleAuth(
      auth: firebase,
      googleSignIn: _GoogleSignIn(),
      messaging: _Messaging(),
    ).signInWithGoogle();
    final oldRejected = expectLater(oldPending, throwsStateError);
    await firestore.writeStarted.future;
    final owner = app_state.prismUser;
    final newGoogle = _GoogleSignIn()..authenticationGate = Completer<GoogleSignInAccount>();
    final newPending = GoogleAuth(auth: firebase, googleSignIn: newGoogle, messaging: _Messaging()).signInWithGoogle();
    await newGoogle.authenticationStarted.future;
    firestore.writeGate.complete();
    await oldRejected;
    expect(firebase.calls, isEmpty);
    expect(app_state.prismUser, same(owner));
    expect(customerInfoStarted.isCompleted, isFalse);
    newGoogle.authenticationGate!.completeError(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));
    expect(await newPending, SignInOutcome.cancelled);
  });

  test('an account switch during the first remote read cannot publish the old sign-in profile', () async {
    firestore.readGate = Completer<void>();
    final pending = completeSignIn(
      user: _User(),
      displayName: 'User',
      email: 'user@example.com',
      photoUrl: '',
      sourceTagPrefix: 'test',
      messaging: _Messaging(),
    );
    final rejected = expectLater(pending, throwsStateError);
    await firestore.readStarted.future;
    final replacement = profileUser(id: 'other');
    app_state.prismUser = replacement;
    firestore.readGate!.complete();
    await rejected;
    expect(app_state.prismUser, same(replacement));
    expect(firestore.writeStarted.isCompleted, isFalse);
  });

  test('an analytics await cannot continue into replacement-session topics or bootstrap', () async {
    firestore.writeGate.complete();
    final analytics = _DelayedAnalytics();
    AnalyticsRuntime.instance = analytics;
    final messaging = _Messaging();
    final pending = completeSignIn(
      user: _User(),
      displayName: 'User',
      email: 'user@example.com',
      photoUrl: '',
      sourceTagPrefix: 'test',
      messaging: messaging,
    );
    final rejected = expectLater(pending, throwsStateError);
    await analytics.started.future;
    app_state.prismUser = profileUser(id: 'other');
    analytics.gate.complete();
    await rejected;
    expect(analytics.userProperties, isEmpty);
    expect(messaging.topics, isEmpty);
    expect(customerInfoStarted.isCompleted, isFalse);
  });

  test('returning to the same profile after a session reset still invalidates an old write', () async {
    final pending = completeSignIn(
      user: _User(),
      displayName: 'User',
      email: 'user@example.com',
      photoUrl: '',
      sourceTagPrefix: 'test',
      messaging: _Messaging(),
    );
    final rejected = expectLater(pending, throwsStateError);
    await firestore.writeStarted.future;
    final original = app_state.prismUser;
    app_state.prismUser = profileUser(id: 'other');
    CoinsService.instance.resetSession();
    app_state.prismUser = original;
    firestore.writeGate.complete();
    await rejected;
    expect(customerInfoStarted.isCompleted, isFalse);
  });

  test('a purchase bootstrap completing after a switch cannot bootstrap replacement coins', () async {
    delayCustomerInfo = true;
    firestore.writeGate.complete();
    await completeSignIn(
      user: _User(),
      displayName: 'User',
      email: 'user@example.com',
      photoUrl: '',
      sourceTagPrefix: 'test',
      messaging: _Messaging(),
    );
    await customerInfoStarted.future;
    final replacement = profileUser(id: 'other');
    app_state.prismUser = replacement;
    customerInfoGate.complete(_customerInfo());
    await waitForSignInBootstraps();
    expect(app_state.prismUser, same(replacement));
    expect(firestore.readTags.where((tag) => tag.startsWith('coins.')), isEmpty);
  });

  for (final Object? storedId in <Object?>['', null, 'another-user', 'u1 ']) {
    test('a user doc with id ${storedId ?? 'missing'} still signs in as the auth uid', () async {
      final Map<String, dynamic> doc = profileUser().toJson()..['id'] = storedId;
      if (storedId == null) doc.remove('id');
      firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{'u1': doc};
      firestore.writeGate.complete();
      final GoogleAuth auth = GoogleAuth(auth: _Auth(), googleSignIn: _GoogleSignIn(), messaging: _Messaging());

      await auth.signInWithGoogle();

      expect(app_state.prismUser.id, 'u1');
      expect(firestore.docs[FirebaseCollections.usersV2]!['u1']!['id'], 'u1');
      expect(firestore.docs[FirebaseCollections.usersV2]!['u1']!['loggedIn'], isTrue);
    });
  }

  group('Google name and photo', () {
    const String oldPhoto = 'https://lh3.googleusercontent.com/a/old=s96-c';
    const String newPhoto = 'https://lh3.googleusercontent.com/a/new=s1337';
    const String sizedNewPhoto = 'https://lh3.googleusercontent.com/a/new=s400-c';
    const String customPhoto = 'https://raw.githubusercontent.com/Hash-Studios/walls/main/u1_1_me.jpg';

    Future<_User> signIn({required String name, required String photo}) async {
      firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{
        'u1': (profileUser(profilePhoto: photo)..name = name).toJson(),
      };
      firestore.writeGate.complete();
      final _User user = _User(displayName: 'Old Name', photoURL: oldPhoto);
      final GoogleAuth auth = GoogleAuth(
        auth: _Auth(user),
        googleSignIn: _GoogleSignIn(_Account(displayName: 'New Name', photoUrl: newPhoto)),
        messaging: _Messaging(),
      );
      await auth.signInWithGoogle();
      return user;
    }

    test('a name and photo from Google follow a change on Google at the next sign-in', () async {
      final _User user = await signIn(name: 'Old Name', photo: oldPhoto);

      final Map<String, dynamic> doc = firestore.docs[FirebaseCollections.usersV2]!['u1']!;
      expect(doc['name'], 'New Name');
      expect(doc['profilePhoto'], sizedNewPhoto);
      expect(app_state.prismUser.name, 'New Name');
      expect(app_state.prismUser.profilePhoto, sizedNewPhoto);
      expect(user.displayName, 'New Name');
      expect(user.photoURL, sizedNewPhoto);
    });

    test('a name and photo set in Prism stay, and Firebase still saves the new Google ones', () async {
      final _User user = await signIn(name: 'My Prism Name', photo: customPhoto);

      final Map<String, dynamic> doc = firestore.docs[FirebaseCollections.usersV2]!['u1']!;
      expect(doc['name'], 'My Prism Name');
      expect(doc['profilePhoto'], customPhoto);
      expect(app_state.prismUser.name, 'My Prism Name');
      expect(app_state.prismUser.profilePhoto, customPhoto);
      expect(user.displayName, 'New Name');
      expect(user.photoURL, sizedNewPhoto);
    });

    for (final String? googlePhoto in <String?>[null, newPhoto]) {
      test('a new account takes ${googlePhoto == null ? 'no photo' : 'the Google photo'}', () async {
        firestore.docs.clear();
        firestore.writeGate.complete();
        final GoogleAuth auth = GoogleAuth(
          auth: _Auth(_User(displayName: 'New Name')),
          googleSignIn: _GoogleSignIn(_Account(displayName: 'New Name', photoUrl: googlePhoto)),
          messaging: _Messaging(),
        );

        await auth.signInWithGoogle();

        final Map<String, dynamic> doc = firestore.docs[FirebaseCollections.usersV2]!['u1']!;
        expect(doc['name'], 'New Name');
        expect(doc['profilePhoto'], googlePhoto == null ? defaultProfilePhotoUrl : sizedNewPhoto);
      });
    }
  });

  test('a Firebase user with a blank stored profile does not count as signed in', () async {
    final GoogleAuth auth = GoogleAuth(auth: _Auth(), googleSignIn: _GoogleSignIn(), messaging: _Messaging());

    app_state.prismUser = profileUser(id: '');
    expect(await auth.isSignedIn(), isFalse);

    app_state.prismUser = profileUser();
    expect(await auth.isSignedIn(), isTrue);
  });

  for (final String invalidProfileId in <String>['null', 'u1 ', 'another-user']) {
    test('a Firebase user with profile id "$invalidProfileId" does not count as signed in', () async {
      final GoogleAuth auth = GoogleAuth(auth: _Auth(), googleSignIn: _GoogleSignIn(), messaging: _Messaging());

      app_state.prismUser = profileUser(id: invalidProfileId);

      expect(await auth.isSignedIn(), isFalse);
    });
  }

  test('sign-out waits for a pending purchase bootstrap before clearing auth state', () async {
    delayCustomerInfo = true;
    final _Auth firebaseAuth = _Auth();
    final GoogleAuth auth = GoogleAuth(auth: firebaseAuth, googleSignIn: _GoogleSignIn(), messaging: _Messaging());
    final Future<Object?> signIn = auth.signInWithGoogle();
    await firestore.writeStarted.future;
    firestore.writeGate.complete();
    await signIn;
    await customerInfoStarted.future;

    final Future<bool> signOut = auth.signOutGoogle();
    await Future<void>.delayed(Duration.zero);
    expect(firebaseAuth.calls, isNot(contains('auth.signOut')));

    customerInfoGate.complete(_customerInfo(premium: true));
    expect(await signOut, isTrue);
    expect(firebaseAuth.calls, contains('auth.signOut'));
    expect(app_state.prismUser.id, isEmpty);
    expect(app_state.prismUser.premium, isFalse);
  });
}

Map<String, Object?> _customerInfo({bool premium = false}) {
  final Map<String, Object?> entitlements = <String, Object?>{};
  if (premium) {
    entitlements['prism_v3_pro_access'] = <String, Object?>{
      'identifier': 'prism_v3_pro_access',
      'isActive': true,
      'willRenew': true,
      'latestPurchaseDate': '2026-09-30T00:00:00Z',
      'originalPurchaseDate': '2026-09-30T00:00:00Z',
      'productIdentifier': 'pro',
      'isSandbox': false,
      'expirationDate': null,
    };
  }
  return <String, Object?>{
    'entitlements': <String, Object?>{'all': entitlements, 'active': entitlements},
    'allPurchaseDates': <String, Object?>{},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': <String>[],
    'nonSubscriptionTransactions': <String>[],
    'firstSeen': '2026-09-30T00:00:00Z',
    'originalAppUserId': 'u1',
    'allExpirationDates': <String, Object?>{},
    'requestDate': '2026-09-30T00:00:00Z',
  };
}
