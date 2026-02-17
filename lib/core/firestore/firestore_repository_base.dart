import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_error.dart';

abstract class FirestoreRepositoryBase {
  FirestoreRepositoryBase(this.firestoreClient);

  final FirestoreClient firestoreClient;

  String mapErrorMessage(String fallback, Object error) {
    if (error is FirestoreError) {
      return '$fallback: ${error.message}';
    }
    return '$fallback: $error';
  }
}
