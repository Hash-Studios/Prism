import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;

class ProfileWallProvider extends ChangeNotifier {
  final Firestore databaseReference = Firestore.instance;
  List profileWalls;
  int len = 0;
  Future<List> getProfileWalls() async {
    profileWalls = [];
    Query db;
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
      profileWalls = [];
      for (final f in value.documents) {
        profileWalls.add(f.data);
      }
      len = profileWalls.length;
      debugPrint(len.toString());
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
    return profileWalls;
  }

  Future<int> getProfileWallsLength() async {
    var tempList = [];
    Query db2;
    if (main.prefs.get('premium') == true) {
      db2 = databaseReference
          .collection("setups")
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("created_at", descending: true);
    } else {
      db2 = databaseReference
          .collection("setups")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("created_at", descending: true);
    }
    await db2.getDocuments().then((value) {
      tempList = [];
      for (final f in value.documents) {
        tempList.add(f.data);
      }
      len = tempList.length;
      debugPrint(len.toString());
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
    main.prefs.put('userSetups', len);
    final len2 = len;
    tempList = [];
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
      for (final f in value.documents) {
        tempList.add(f.data);
      }
      len = tempList.length;
      debugPrint(len.toString());
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
    main.prefs.put('userPosts', len);
    return len + len2;
  }
}
