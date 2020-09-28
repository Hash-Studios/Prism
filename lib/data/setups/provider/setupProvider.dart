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
