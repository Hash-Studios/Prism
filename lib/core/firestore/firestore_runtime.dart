import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';

FirestoreClient get firestoreClient => getIt<FirestoreClient>();
