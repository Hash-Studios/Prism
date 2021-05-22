import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;

class ProfileWallProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List? profileWalls;
  int len = 0;
  Future<List?> getProfileWalls() async {
    profileWalls = [];
    Query db;
    if (globals.prismUser.premium == true) {
      db = databaseReference
          .collection("walls")
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("createdAt", descending: true);
    } else {
      db = databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("createdAt", descending: true);
    }
    await db.get().then((value) {
      profileWalls = [];
      for (final f in value.docs) {
        profileWalls!.add(f.data());
      }
      len = profileWalls!.length;
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
    if (globals.prismUser.premium == true) {
      db2 = databaseReference
          .collection("setups")
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("created_at", descending: true);
    } else {
      db2 = databaseReference
          .collection("setups")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("created_at", descending: true);
    }
    await db2.get().then((value) {
      tempList = [];
      for (final f in value.docs) {
        tempList.add(f.data());
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
    if (globals.prismUser.premium == true) {
      db2 = databaseReference
          .collection("walls")
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("createdAt", descending: true);
    } else {
      db2 = databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("createdAt", descending: true);
    }
    await db2.get().then((value) {
      tempList = [];
      for (final f in value.docs) {
        tempList.add(f.data());
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
