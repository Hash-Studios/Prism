import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_firestore_client.dart';
import '../support/in_memory_local_store.dart';
import '../support/profile_user_fixture.dart';

class _DelayedWriteFirestore extends FakeFirestoreClient {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> writeGate = Completer<void>();
  bool _blockedOnce = false;
  final List<String> readTags = <String>[];

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    readTags.add(sourceTag);
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
  _User({this.displayName = 'User', this.photoURL});

  @override
  String get uid => 'u1';
  @override
  String? get email => 'user@example.com';
  @override
  String? displayName;
  @override
  String? photoURL;
  @override
  bool get isAnonymous => false;
  @override
  Future<void> updateDisplayName(String? displayName) async => this.displayName = displayName;
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

  final _User user;
  final List<String> calls = <String>[];

  @override
  User? get currentUser => user;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async => _Credential(user);
  @override
  Future<void> signOut() async => calls.add('auth.signOut');
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

  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}
  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) async => account;
  @override
  Future<void> signOut() async {}
}

class _Messaging extends Fake implements FirebaseMessaging {
  @override
  Future<String?> getAPNSToken() async => 'apns';
  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
  @override
  Future<void> subscribeToTopic(String topic) async {}
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel purchasesChannel = MethodChannel('purchases_flutter');
  late _DelayedWriteFirestore firestore;
  late bool delayCustomerInfo;
  late Completer<void> customerInfoStarted;
  late Completer<Map<String, Object?>> customerInfoGate;

  setUp(() async {
    await getIt.reset();
    firestore = _DelayedWriteFirestore();
    firestore.docs[FirebaseCollections.usersV2] = <String, Map<String, dynamic>>{'u1': profileUser().toJson()};
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
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
