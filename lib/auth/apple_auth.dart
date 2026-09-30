import 'dart:convert';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/post_sign_in.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<SignInOutcome> signInWithApple() async {
    logger.i('signInWithApple start', tag: 'AppleAuth');
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );

      // The Apple-specific credential; the generic OAuthProvider('apple.com') path fails on iOS with invalid-credential.
      final oauthCredential = AppleAuthProvider.credentialWithIDToken(
        appleCredential.identityToken!,
        rawNonce,
        AppleFullPersonName(givenName: appleCredential.givenName, familyName: appleCredential.familyName),
      );

      final UserCredential authResult = await _auth.signInWithCredential(oauthCredential);
      final User? user = authResult.user;

      if (user == null) {
        throw Exception('Apple sign-in returned null user');
      }

      // Apple only provides the name on the very first sign-in.
      final String displayName = (appleCredential.givenName ?? '').isNotEmpty
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
          : user.displayName ?? user.email?.split('@')[0] ?? 'Prism User';

      if ((appleCredential.givenName ?? '').isNotEmpty && user.displayName == null) {
        await user.updateDisplayName(displayName);
      }

      final String email = appleCredential.email ?? user.email ?? '';
      final String photoURL = user.photoURL ?? app_state.defaultProfilePhotoUrl;

      await completeSignIn(
        user: user,
        displayName: displayName,
        email: email,
        photoUrl: photoURL,
        sourceTagPrefix: 'apple_auth.signin',
      );
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.apple,
          result: EventResultValue.success,
          sourceContext: 'apple_auth',
        ),
      );
      return SignInOutcome.signedIn;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        await analytics.track(
          const AuthLoginResultEvent(
            method: AuthMethodValue.apple,
            result: EventResultValue.cancelled,
            reason: AnalyticsReasonValue.userCancelled,
            sourceContext: 'apple_auth',
          ),
        );
        logger.i('signInWithApple canceled by user', tag: 'AppleAuth');
        return SignInOutcome.cancelled;
      }
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.apple,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'apple_auth',
        ),
      );
      logger.e('signInWithApple authorization failed', tag: 'AppleAuth', error: e);
      rethrow;
    } catch (e, st) {
      await analytics.track(
        const AuthLoginResultEvent(
          method: AuthMethodValue.apple,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
          sourceContext: 'apple_auth',
        ),
      );
      logger.e('signInWithApple failed', tag: 'AppleAuth', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Re-authenticates with a fresh Apple credential, then revokes the Sign in
  /// with Apple authorization. Required by Apple before account deletion
  /// (HIG: apps must let users revoke "Sign in with Apple" on deletion).
  Future<void> reauthenticateCurrentUser() async {
    final rawNonce = _generateNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
      nonce: _sha256ofString(rawNonce),
    );
    final oauthCredential = AppleAuthProvider.credentialWithIDToken(
      credential.identityToken!,
      rawNonce,
      AppleFullPersonName(),
    );
    await _auth.currentUser!.reauthenticateWithCredential(oauthCredential);
    if (credential.authorizationCode.isNotEmpty) {
      await _auth.revokeTokenWithAuthorizationCode(credential.authorizationCode);
    }
  }
}
