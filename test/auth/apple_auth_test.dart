import 'package:Prism/auth/apple_auth.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/monitoring/monitoring_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_firestore_client.dart';
import '../support/profile_user_fixture.dart';

final List<String> _calls = <String>[];

class _FailingAnalytics extends FakeAppAnalytics {
  @override
  Future<void> track(AnalyticsEvent event) => Future<void>.error(StateError('analytics unavailable'));
}

class _FailingReadFirestore extends FakeFirestoreClient {
  _FailingReadFirestore(this.error);

  final Object error;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) => Future<T?>.error(error);

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) {
    _calls.add('firestore.update $collection/$id $data');
    return super.updateDoc(collection, id, data, sourceTag: sourceTag);
  }
}

class _User extends Fake implements User {
  @override
  String get uid => 'apple-user';
  @override
  String? get email => 'user@example.com';
  @override
  String? get displayName => 'Apple User';
  @override
  String? get photoURL => null;
}

class _Credential extends Fake implements UserCredential {
  _Credential(this._user);
  final User _user;
  @override
  User? get user => _user;
}

class _Auth extends Fake implements FirebaseAuth {
  User? user;
  @override
  User? get currentUser => user;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    _calls.add('auth.signIn');
    user = _User();
    return _Credential(user!);
  }

  @override
  Future<void> signOut() async {
    _calls.add('auth.signOut');
    user = null;
  }
}

class _GoogleSignIn extends Fake implements GoogleSignIn {
  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}
  @override
  Future<void> signOut() async {}
}

class _Messaging extends Fake implements FirebaseMessaging {
  @override
  Future<String?> getAPNSToken() async => 'apns';
  @override
  Future<void> unsubscribeFromTopic(String topic) async => _calls.add('fcm.unsubscribe $topic');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel appleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');

  setUp(() async {
    _calls.clear();
    AnalyticsRuntime.reset();
    MonitoringRuntime.reset();
    await getIt.reset();
  });

  tearDown(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    AnalyticsRuntime.reset();
    MonitoringRuntime.reset();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(appleChannel, null);
  });

  Future<void> runPostCredentialFailure(Object error, {SignInOutcome? expectedOutcome}) async {
    final _Auth firebaseAuth = _Auth();
    final _FailingReadFirestore firestore = _FailingReadFirestore(error);
    getIt.registerSingleton<FirestoreClient>(firestore);
    final GoogleAuth googleAuth = GoogleAuth(
      auth: firebaseAuth,
      googleSignIn: _GoogleSignIn(),
      messaging: _Messaging(),
    );
    AnalyticsRuntime.instance = _FailingAnalytics();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      appleChannel,
      (MethodCall call) async => <String, Object?>{
        'type': 'appleid',
        'authorizationCode': 'code',
        'identityToken': 'identity-token',
        'userIdentifier': 'apple-user',
        'email': 'user@example.com',
      },
    );

    final Future<SignInOutcome> signIn = AppleAuth(auth: firebaseAuth, googleAuth: googleAuth).signInWithApple();
    if (expectedOutcome != null) {
      expect(await signIn, expectedOutcome);
    } else {
      await expectLater(signIn, throwsA(same(error)));
    }

    expect(_calls.first, 'auth.signIn');
    expect(_calls.where((String call) => call == 'auth.signOut'), hasLength(1));
    expect(firebaseAuth.currentUser, isNull);
  }

  test('Apple rolls Firebase back when post-credential analytics fails', () async {
    await runPostCredentialFailure(StateError('server unavailable'));
  });

  test('Apple rolls Firebase back for a post-credential cancellation', () async {
    const SignInWithAppleAuthorizationException error = SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.canceled,
      message: 'cancelled after Firebase accepted the credential',
    );
    await runPostCredentialFailure(error, expectedOutcome: SignInOutcome.cancelled);
  });

  test('Apple preserves a post-credential authorization failure when analytics fails', () async {
    const SignInWithAppleAuthorizationException error = SignInWithAppleAuthorizationException(
      code: AuthorizationErrorCode.failed,
      message: 'authorization failed after Firebase accepted the credential',
    );
    await runPostCredentialFailure(error);
  });
}
