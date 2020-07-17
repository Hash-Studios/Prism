import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;

class ProfileWallProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List profileWalls;
  Future<List> getProfileWalls() async {
    this.profileWalls = [];
    await databaseReference
        .collection("walls2")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: main.prefs.getString('email'))
        .orderBy("createdAt", descending: true)
        .getDocuments()
        .then((value) {
      this.profileWalls = [];
      value.documents.forEach((f) {
        this.profileWalls.add(f.data);
      });
      print(this.profileWalls.length);
    }).catchError((e) {
      print(e.toString());
      print("data done with error");
    });
    return this.profileWalls;
  }
}
