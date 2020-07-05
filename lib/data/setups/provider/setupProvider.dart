import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;

class SetupProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List setups;
  Future<List> getDataBase() async {
    this.setups = [];
    await databaseReference.collection("setups").getDocuments().then((value) {
      value.documents.forEach((f) => this.setups.add(f.data));
      print(this.setups);
    }).catchError((e) {
      print("data done with error");
    });
    return this.setups;
  }
}
