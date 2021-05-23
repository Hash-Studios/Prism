import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SetupProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot>? setups;
  Future<void> getSetups() async {
    debugPrint("Fetching first 10 setups");
    setups = [];
    await databaseReference
        .collection("setups")
        .where("review", isEqualTo: true)
        .orderBy("created_at", descending: true)
        .limit(10)
        .get()
        .then((value) {
      setups = value.docs;
    });
    notifyListeners();
  }

  Future<void> seeMoreSetups() async {
    debugPrint("Fetching more setups");
    await databaseReference
        .collection("setups")
        .where("review", isEqualTo: true)
        .orderBy("created_at", descending: true)
        .startAfterDocument(setups![setups!.length - 1])
        .limit(10)
        .get()
        .then((value) {
      for (final doc in value.docs) {
        setups!.add(doc);
      }
    });
    notifyListeners();
  }
}

final databaseReference = FirebaseFirestore.instance;
Map? setup;
Future<Map?> getSetupFromName(String? name) async {
  setup = {};
  await databaseReference
      .collection("setups")
      .where("name", isEqualTo: name)
      .get()
      .then((value) {
    value.docs.forEach((f) => setup = f.data());
    debugPrint(setup.toString());
  }).catchError((e) {
    debugPrint("data done with error");
  });
  return setup;
}
