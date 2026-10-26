import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreError implements Exception {
  FirestoreError({required this.message, this.code, this.original});

  final String message;
  final String? code;
  final Object? original;

  @override
  String toString() => 'FirestoreError(code: $code, message: $message)';
}

/// Firebase is not ready, so the client did not open Firestore. The `unavailable` code makes callers and Sentry treat it
/// like a lost connection.
class FirestoreNotReadyError extends FirestoreError {
  FirestoreNotReadyError()
    : super(
        code: 'unavailable',
        message: 'Firebase is not ready.',
        original: FirebaseException(plugin: 'core', code: 'unavailable'),
      );
}

FirestoreError mapFirestoreError(Object error) {
  if (error is FirestoreError) {
    return error;
  }
  if (error is FirebaseException) {
    return FirestoreError(code: error.code, message: error.message ?? error.toString(), original: error);
  }
  return FirestoreError(message: error.toString(), original: error);
}
