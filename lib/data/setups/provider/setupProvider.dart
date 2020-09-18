import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SetupProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List setups;
  Future<List> getDataBase() async {
    this.setups = [];
    await databaseReference
        .collection("setups")
        .orderBy("createdAt")
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
