import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;

class ProfileWallProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List profileWalls;
  int len = 0;
  Future<List> getProfileWalls() async {
    this.profileWalls = [];
    await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: main.prefs.get('email'))
        .orderBy("createdAt", descending: true)
        .getDocuments()
        .then((value) {
      this.profileWalls = [];
      value.documents.forEach((f) {
        this.profileWalls.add(f.data);
      });
      this.len = this.profileWalls.length;
      print(this.len);
    }).catchError((e) {
      print(e.toString());
      print("data done with error");
    });
    return this.profileWalls;
  }
}
