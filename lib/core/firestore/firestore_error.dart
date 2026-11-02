import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreError implements Exception {
  FirestoreError({required this.message, this.code, this.original, this.operation, this.collection, this.sourceTag});

  final String message;
  final String? code;
  final Object? original;

  /// Firestore operation name, for example `docGet` or `queryGet`.
  final String? operation;

  /// Collection path with document ids replaced by `{id}`.
  final String? collection;

  /// Static call-site label. It is not user data.
  final String? sourceTag;

  FirestoreError withCall({required String operation, required String collection, required String sourceTag}) {
    return FirestoreError(
      message: message,
      code: code,
      original: original,
      operation: operation,
      collection: collection,
      sourceTag: sourceTag,
    );
  }

  @override
  String toString() {
    final String where = <String>[
      if (operation != null) 'operation: $operation',
      if (collection != null) 'collection: $collection',
      if (sourceTag != null) 'sourceTag: $sourceTag',
    ].join(', ');
    return 'FirestoreError(code: $code, message: $message${where.isEmpty ? '' : ', $where'})';
  }
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
