import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/firestore/firestore_tracked_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final FirestoreClient firestoreClient = FirestoreTrackedClient(
  FirebaseFirestore.instance,
  CompositeFirestoreTelemetrySink(
    <FirestoreTelemetrySink>[
      const FirestoreConsoleTelemetrySink(),
      FirestoreFileTelemetrySink(),
    ],
  ),
);
