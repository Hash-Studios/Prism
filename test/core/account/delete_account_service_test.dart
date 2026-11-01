// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/core/account/delete_account_service.dart';
import 'package:Prism/core/account/reauth_cancelled.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../support/profile_user_fixture.dart';

class _DelayedFirebaseCore extends MockFirebaseApp {
  final ready = Completer<void>();

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => <CoreInitializeResponse>[];

  @override
  Future<CoreInitializeResponse> initializeApp(String name, CoreFirebaseOptions options) async {
    await ready.future;
    return CoreInitializeResponse(name: name, options: options, pluginConstants: <String, Object?>{});
  }
}

class _NoMultiFactor extends MultiFactorPlatform {
  _NoMultiFactor(super.auth);
}

class _AppleUser extends UserPlatform {
  _AppleUser(FirebaseAuthPlatform auth, this.calls)
    : super(
        auth,
        _NoMultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'user-1',
            email: 'apple@example.com',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: const <Map<Object?, Object?>?>[
            <String, Object?>{'providerId': 'apple.com', 'uid': 'apple-1'},
          ],
        ),
      );

  final List<String> calls;

  @override
  Future<UserCredentialPlatform> reauthenticateWithCredential(AuthCredential credential) async {
    calls.add('reauth:${credential.providerId}');
    return _Credential(auth, this, credential);
  }
}

class _Credential extends UserCredentialPlatform {
  _Credential(FirebaseAuthPlatform auth, UserPlatform user, AuthCredential credential)
    : super(auth: auth, user: user, credential: credential);
}

class _RestoredAppleAuth extends FirebaseAuthPlatform {
  _RestoredAppleAuth(this.calls);

  final List<String> calls;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform get currentUser => _AppleUser(this, calls);

  @override
  Future<void> revokeTokenWithAuthorizationCode(String authorizationCode) async =>
      calls.add('revoke:$authorizationCode');
}

class _UnexpectedGoogleSignIn extends GoogleSignInPlatform {
  _UnexpectedGoogleSignIn(this.calls);

  final List<String> calls;

  @override
  Future<void> init(InitParameters params) async => calls.add('google.init');

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async {
    calls.add('google.authenticate');
    throw StateError('An Apple account must not open Google authentication.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;

  DeleteAccountService build({Future<void> Function()? reauthenticate, Future<void> Function()? deleteOnServer}) {
    return DeleteAccountService(
      reauthenticate: reauthenticate ?? () async => calls.add('reauth'),
      deleteOnServer: deleteOnServer ?? () async => calls.add('server'),
      signOut: () async {
        calls.add('signOut');
        return true;
      },
      clearLocalData: (String userId) async => calls.add('clear:$userId'),
    );
  }

  setUp(() {
    calls = <String>[];
    app_state.prismUser = profileUser(id: 'user-1');
  });

  tearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());

  testWidgets('waits for Firebase before selecting the restored Apple deletion provider', (tester) async {
    const MethodChannel appleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final previousAuth = FirebaseAuthPlatform.instance;
    final previousGoogleSignIn = GoogleSignInPlatform.instance;
    final core = _DelayedFirebaseCore();
    TestFirebaseCoreHostApi.setUp(core);
    FirebaseAuthPlatform.instance = _RestoredAppleAuth(calls);
    GoogleSignInPlatform.instance = _UnexpectedGoogleSignIn(calls);
    messenger.setMockMethodCallHandler(appleChannel, (call) async {
      calls.add('apple.prompt');
      return <String, Object?>{
        'type': 'appleid',
        'authorizationCode': 'apple-code',
        'identityToken': 'apple-token',
        'userIdentifier': 'apple-1',
      };
    });
    addTearDown(() {
      FirebaseAuthPlatform.instance = previousAuth;
      GoogleSignInPlatform.instance = previousGoogleSignIn;
      messenger.setMockMethodCallHandler(appleChannel, null);
      TestFirebaseCoreHostApi.setUp(null);
    });
    final initialization = Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-key',
        appId: 'test-app',
        messagingSenderId: 'test-sender',
        projectId: 'demo-prism',
      ),
    );
    FirebaseInit.setFuture(initialization.then((_) => true));
    await tester.pump();
    expect(Firebase.apps, isEmpty);
    final service = DeleteAccountService(
      deleteOnServer: () async => calls.add('server'),
      signOut: () async {
        calls.add('signOut');
        return true;
      },
      clearLocalData: (userId) async => calls.add('clear:$userId'),
    );
    Object? failure;
    final deletion = service.deleteAccount().then<void>(
      (_) {},
      onError: (Object error) {
        failure = error;
      },
    );
    await tester.pump();
    expect(calls, isEmpty, reason: 'Provider selection must wait for Firebase to restore its user.');

    core.ready.complete();
    await tester.pump();
    await initialization;
    await deletion;

    expect(calls, <String>[
      'apple.prompt',
      'reauth:apple.com',
      'revoke:apple-code',
      'server',
      'signOut',
      'clear:user-1',
    ]);
    expect(failure, isNull);
  });

  test('re-authenticates, deletes on the server, signs out, then clears this device', () async {
    await build().deleteAccount();

    expect(calls, <String>['reauth', 'server', 'signOut', 'clear:user-1']);
  });

  test('a cancelled re-authentication stops before the server and leaves local data alone', () async {
    final service = build(
      reauthenticate: () async => throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );

    await expectLater(service.deleteAccount(), throwsA(isA<GoogleSignInException>()));

    expect(calls, isEmpty);
  });

  test('a server failure keeps the local data', () async {
    final service = build(deleteOnServer: () async => throw StateError('server down'));

    await expectLater(service.deleteAccount(), throwsStateError);

    expect(calls, <String>['reauth']);
  });

  test('the server call may run as long as a batch delete needs', () {
    expect(DeleteAccountService.serverTimeout, const Duration(seconds: 300));
  });

  group('isReauthCancelled', () {
    test('is true for a closed Google or Apple prompt', () {
      expect(isReauthCancelled(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled)), isTrue);
      expect(
        isReauthCancelled(
          const SignInWithAppleAuthorizationException(code: AuthorizationErrorCode.canceled, message: ''),
        ),
        isTrue,
      );
    });

    test('is false for real failures', () {
      expect(isReauthCancelled(const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError)), isFalse);
      expect(
        isReauthCancelled(
          const SignInWithAppleAuthorizationException(code: AuthorizationErrorCode.failed, message: ''),
        ),
        isFalse,
      );
      expect(isReauthCancelled(StateError('no token')), isFalse);
    });
  });
}
