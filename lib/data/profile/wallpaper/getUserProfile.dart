import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

final Firestore databaseReference = Firestore.instance;
List userProfileWalls;
int len = 0;
Future<List> getuserProfileWalls(String email) async {
  userProfileWalls = [];
  await databaseReference
      .collection("walls")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("createdAt", descending: true)
      .getDocuments()
      .then((value) {
    userProfileWalls = [];
    for (final f in value.documents) {
      userProfileWalls.add(f.data);
    }
    len = userProfileWalls.length;
    debugPrint(len.toString());
  }).catchError((e) {
    debugPrint(e.toString());
    debugPrint("data done with error");
  });
  return userProfileWalls;
}

Future<int> getProfileWallsLength(String email) async {
  var tempList = [];
  await databaseReference
      .collection("walls")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("createdAt", descending: true)
      .getDocuments()
      .then((value) {
    tempList = [];
    value.documents.forEach((f) {
      tempList.add(f.data);
    });
    len = tempList.length;
    debugPrint(len.toString());
  }).catchError((e) {
    debugPrint(e.toString());
    debugPrint("data done with error");
  });
  return len;
}
