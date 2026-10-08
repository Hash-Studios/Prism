import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../support/fake_app_analytics.dart';

class _Auth extends Fake implements FirebaseAuth {}

class _ThrowingGoogleSignIn extends Fake implements GoogleSignIn {
  _ThrowingGoogleSignIn(this.code);

  final GoogleSignInExceptionCode code;

  @override
  Future<void> initialize({String? clientId, String? serverClientId, String? nonce, String? hostedDomain}) async {}

  @override
  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const <String>[]}) =>
      Future<GoogleSignInAccount>.error(GoogleSignInException(code: code));
}

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  test('the user closing the Google sheet is a cancellation', () async {
    final GoogleAuth auth = GoogleAuth(
      auth: _Auth(),
      googleSignIn: _ThrowingGoogleSignIn(GoogleSignInExceptionCode.canceled),
    );

    expect(await auth.signInWithGoogle(), SignInOutcome.cancelled);
  });

  test('an unknown Google error is thrown so the screen can show a real message', () async {
    final GoogleAuth auth = GoogleAuth(
      auth: _Auth(),
      googleSignIn: _ThrowingGoogleSignIn(GoogleSignInExceptionCode.unknownError),
    );

    await expectLater(auth.signInWithGoogle(), throwsA(isA<GoogleSignInException>()));
  });

  group('googleSignInErrorMessage', () {
    test('unknownError says sign-in failed instead of cancelled', () {
      final String message = googleSignInErrorMessage(
        const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError),
      );

      expect(message, 'Google sign-in failed. Check your connection and try again.');
      expect(message.toLowerCase(), isNot(contains('cancel')));
    });

    test('a missing Play services provider is named on Android only', () {
      const GoogleSignInException error = GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
      );

      expect(
        googleSignInErrorMessage(error, platform: TargetPlatform.android),
        'Google Play services on this device cannot sign in.',
      );
      expect(googleSignInErrorMessage(error, platform: TargetPlatform.iOS), genericSignInErrorMessage);
    });

    test('anything else gets the generic message', () {
      expect(googleSignInErrorMessage(StateError('x')), genericSignInErrorMessage);
    });
  });
}
