import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// True when the user closed the Google or Apple confirmation. That is a choice, not a failure.
bool isReauthCancelled(Object error) {
  if (error is GoogleSignInException) return error.code == GoogleSignInExceptionCode.canceled;
  if (error is SignInWithAppleAuthorizationException) return error.code == AuthorizationErrorCode.canceled;
  return false;
}
