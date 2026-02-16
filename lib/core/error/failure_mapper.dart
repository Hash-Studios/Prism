import 'package:Prism/core/error/failure.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

Failure mapExceptionToFailure(Object error) {
  if (error is FirebaseException) {
    return ServerFailure(error.message ?? 'Firebase error', code: error.code);
  }
  if (error is FirebaseAuthException) {
    return ValidationFailure(error.message ?? 'Authentication error',
        code: error.code);
  }
  if (error is PlatformException) {
    return UnknownFailure(error.message ?? 'Platform error', code: error.code);
  }
  if (error is FormatException) {
    return ValidationFailure(error.message);
  }
  return UnknownFailure(error.toString());
}
