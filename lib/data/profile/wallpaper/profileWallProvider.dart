import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;

class ProfileWallProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List profileWalls;
  int len = 0;
  Future<List> getProfileWalls() async {
    this.profileWalls = [];
    var db;
    if (main.prefs.get('premium') == true) {
      db = databaseReference
          .collection("walls")
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("createdAt", descending: true);
    } else {
      db = databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("createdAt", descending: true);
    }
    await db.getDocuments().then((value) {
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

  Future<int> getProfileWallsLength() async {
    var tempList = [];
    var db2;
    if (main.prefs.get('premium') == true) {
      db2 = databaseReference
          .collection("walls")
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("createdAt", descending: true);
    } else {
      db2 = databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("createdAt", descending: true);
    }
    await db2.getDocuments().then((value) {
      tempList = [];
      value.documents.forEach((f) {
        tempList.add(f.data);
      });
      this.len = tempList.length;
      print(this.len);
    }).catchError((e) {
      print(e.toString());
      print("data done with error");
    });
    main.prefs.put('userPosts', this.len);
    return this.len;
  }
}
