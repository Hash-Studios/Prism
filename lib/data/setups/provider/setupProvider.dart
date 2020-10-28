import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SetupProvider extends ChangeNotifier {
  final Firestore databaseReference = Firestore.instance;
  List setups;
  Future<List> getDataBase() async {
    setups = [];
    await databaseReference
        .collection("setups")
        .orderBy("created_at", descending: true)
        .where("review", isEqualTo: true)
        .getDocuments()
        .then((value) {
      for (final f in value.documents) {
        setups.add(f.data);
      }
      debugPrint(setups.toString());
    }).catchError((e) {
      debugPrint("data done with error");
    });
    return setups;
  }
}

final databaseReference2 = Firestore.instance;
Map setup;
Future<Map> getSetupFromName(String name) async {
  setup = {};
  await databaseReference2
      .collection("setups")
      .where("name", isEqualTo: name)
      .getDocuments()
      .then((value) {
    value.documents.forEach((f) => setup = f.data);
    debugPrint(setup.toString());
  }).catchError((e) {
    debugPrint("data done with error");
  });
  return setup;
}
