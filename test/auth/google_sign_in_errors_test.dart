import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_app_analytics.dart';

class _Auth extends Fake implements FirebaseAuth {
  _Auth({FirebaseAuthException? webError}) : webError = webError ?? FirebaseAuthException(code: 'web-context-canceled');

  final FirebaseAuthException webError;
  final List<AuthProvider> webProviders = <AuthProvider>[];

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) {
    webProviders.add(provider);
    return Future<UserCredential>.error(webError);
  }
}

class _CountingGoogleSignIn extends Fake implements GoogleSignIn {
  int authenticateCalls = 0;

  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}

  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) {
    authenticateCalls++;
    return Future<GoogleSignInAccount>.error(StateError('Google sheet should not open'));
  }
}

class _ThrowingGoogleSignIn extends Fake implements GoogleSignIn {
  _ThrowingGoogleSignIn(this.code, [this.description]);

  final GoogleSignInExceptionCode code;
  final String? description;

  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}

  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) =>
      Future<GoogleSignInAccount>.error(GoogleSignInException(code: code, description: description));
}

// The exact error google_sign_in_android 7.2 throws for Credential Manager's NoCredentialException (PRISM-J4).
_ThrowingGoogleSignIn _noCredential() => _ThrowingGoogleSignIn(
  GoogleSignInExceptionCode.unknownError,
  'No credential available: No credentials available on this device.',
);

Iterable<AppLogRecord> _errorLogs() =>
    InMemoryLogSink.instance.records.where((AppLogRecord record) => record.level == AppLogLevel.error);

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    InMemoryLogSink.instance.clear();
  });
  tearDown(() {
    AnalyticsRuntime.reset();
    debugDefaultTargetPlatformOverride = null;
  });

  test('the user closing the Google sheet is a cancellation', () async {
    final GoogleAuth auth = GoogleAuth(
      auth: _Auth(),
      googleSignIn: _ThrowingGoogleSignIn(GoogleSignInExceptionCode.canceled),
    );

    expect(await auth.signInWithGoogle(), SignInOutcome.cancelled);
  });

  test('sign-in fails when Firebase never starts, before the Google sheet', () async {
    final _CountingGoogleSignIn google = _CountingGoogleSignIn();
    final GoogleAuth auth = GoogleAuth(googleSignIn: google, firebaseReady: () async => false);

    await expectLater(auth.signInWithGoogle(), throwsA(isA<FirebaseUnavailableException>()));
    expect(google.authenticateCalls, 0);
    expect(
      googleSignInErrorMessage(const FirebaseUnavailableException(), l10n, platform: TargetPlatform.android),
      'Google Play services on this device cannot sign in.',
    );
    expect(
      googleSignInErrorMessage(const FirebaseUnavailableException(), l10n, platform: TargetPlatform.iOS),
      genericSignInErrorMessage(l10n),
    );
  });

  test('an unknown Google error is thrown so the screen can show a real message', () async {
    final GoogleAuth auth = GoogleAuth(
      auth: _Auth(),
      googleSignIn: _ThrowingGoogleSignIn(GoogleSignInExceptionCode.unknownError),
    );

    await expectLater(auth.signInWithGoogle(), throwsA(isA<GoogleSignInException>()));
  });

  group('Android Credential Manager cannot show an account', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('no credential opens Google web sign-in, and closing it is a quiet cancellation', () async {
      final _Auth firebase = _Auth();
      final GoogleAuth auth = GoogleAuth(auth: firebase, googleSignIn: _noCredential());

      expect(await auth.signInWithGoogle(), SignInOutcome.cancelled);
      final GoogleAuthProvider provider = firebase.webProviders.single as GoogleAuthProvider;
      expect(provider.providerId, 'google.com');
      expect(provider.parameters, <String, String>{'prompt': 'select_account'});
      expect(_errorLogs(), isEmpty);
    });

    test('a missing Credential Manager provider opens Google web sign-in', () async {
      final _Auth firebase = _Auth();
      final GoogleAuth auth = GoogleAuth(
        auth: firebase,
        googleSignIn: _ThrowingGoogleSignIn(
          GoogleSignInExceptionCode.providerConfigurationError,
          'getCredentialAsync no provider dependencies found - please ensure the desired provider dependencies are added',
        ),
      );

      expect(await auth.signInWithGoogle(), SignInOutcome.cancelled);
      expect(firebase.webProviders, hasLength(1));
      expect(_errorLogs(), isEmpty);
    });

    test('a web sign-in failure reaches the screen and is reported', () async {
      final _Auth firebase = _Auth(webError: FirebaseAuthException(code: 'internal-error'));
      final GoogleAuth auth = GoogleAuth(auth: firebase, googleSignIn: _noCredential());

      await expectLater(
        auth.signInWithGoogle(),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'internal-error')),
      );
      expect(_errorLogs().single.message, 'signInWithGoogle failed');
    });

    test('other Google errors do not open web sign-in', () async {
      final _Auth firebase = _Auth();
      final GoogleAuth auth = GoogleAuth(
        auth: firebase,
        googleSignIn: _ThrowingGoogleSignIn(GoogleSignInExceptionCode.unknownError, 'network down'),
      );

      await expectLater(auth.signInWithGoogle(), throwsA(isA<GoogleSignInException>()));
      expect(firebase.webProviders, isEmpty);
    });
  });

  test('no credential on iOS is not sent to web sign-in', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final _Auth firebase = _Auth();
    final GoogleAuth auth = GoogleAuth(auth: firebase, googleSignIn: _noCredential());

    await expectLater(auth.signInWithGoogle(), throwsA(isA<GoogleSignInException>()));
    expect(firebase.webProviders, isEmpty);
  });

  group('googleSignInErrorMessage', () {
    test('unknownError says sign-in failed instead of cancelled', () {
      final String message = googleSignInErrorMessage(
        const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError),
        l10n,
      );

      expect(message, 'Google sign-in failed. Check your connection and try again.');
      expect(message.toLowerCase(), isNot(contains('cancel')));
    });

    test('web sign-in with no connection asks the user to check it', () {
      expect(
        googleSignInErrorMessage(FirebaseAuthException(code: 'network-request-failed'), l10n),
        'Google sign-in failed. Check your connection and try again.',
      );
    });

    test('anything else gets the generic message', () {
      expect(googleSignInErrorMessage(StateError('x'), l10n), genericSignInErrorMessage(l10n));
    });
  });
}
