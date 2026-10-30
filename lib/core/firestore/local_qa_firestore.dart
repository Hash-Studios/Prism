import 'package:Prism/env/env.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configure the Firestore transport before DI resolves any client.
void configureLocalQaFirestore() {
  if (!kDebugMode || !Env.localQa || Firebase.app().options.projectId != 'demo-prism') {
    throw StateError('Local QA Firestore requires a demo-prism debug app.');
  }
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 19372, automaticHostMapping: false);
}
