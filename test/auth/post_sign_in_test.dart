import 'dart:async';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
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
  @override
  String get uid => 'u1';
  @override
  String? get email => 'user@example.com';
  @override
  String? get displayName => 'User';
  @override
  String? get photoURL => null;
}

class _Credential extends Fake implements UserCredential {
  @override
  User? get user => _User();
}

class _Auth extends Fake implements FirebaseAuth {
  final List<String> calls = <String>[];

  @override
  User? get currentUser => _User();
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async => _Credential();
  @override
  Future<void> signOut() async => calls.add('auth.signOut');
}

// ignore: avoid_implementing_value_types
class _Account extends Fake implements GoogleSignInAccount {
  @override
  GoogleSignInAuthentication get authentication => const GoogleSignInAuthentication(idToken: 'id-token');
}

class _GoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}
  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) async => _Account();
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
