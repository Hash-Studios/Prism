import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SetupProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List setups;
  Future<List> getDataBase() async {
    this.setups = [];
    await databaseReference
        .collection("setups")
        .orderBy("created_at", descending: true)
        .where("review", isEqualTo: true)
        .getDocuments()
        .then((value) {
      value.documents.forEach((f) => this.setups.add(f.data));
      print(this.setups);
    }).catchError((e) {
      print("data done with error");
    });
    return this.setups;
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
    print(setup);
  }).catchError((e) {
    print("data done with error");
  });
  return setup;
}
