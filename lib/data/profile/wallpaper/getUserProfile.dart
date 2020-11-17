import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/main.dart' as main;
import 'package:flutter/material.dart';

final Firestore databaseReference = Firestore.instance;
List userProfileWalls;
List userProfileSetups;
int len = 0;
int len2 = 0;
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

Future<List> getUserProfileSetups(String email) async {
  userProfileSetups = [];
  await databaseReference
      .collection("setups")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("created_at", descending: true)
      .getDocuments()
      .then((value) {
    userProfileSetups = [];
    for (final f in value.documents) {
      userProfileSetups.add(f.data);
    }
    len2 = userProfileSetups.length;
    debugPrint(len.toString());
  }).catchError((e) {
    debugPrint(e.toString());
    debugPrint("data done with error");
  });
  return userProfileSetups;
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

Future<int> getProfileSetupsLength(String email) async {
  var tempList = [];
  await databaseReference
      .collection("setups")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("created_at", descending: true)
      .getDocuments()
      .then((value) {
    tempList = [];
    value.documents.forEach((f) {
      tempList.add(f.data);
    });
    len2 = tempList.length;
    debugPrint(len2.toString());
  }).catchError((e) {
    debugPrint(e.toString());
    debugPrint("data done with error");
  });
  return len2;
}

Future setUserTwitter(String twitter, String id) async {
  await databaseReference
      .collection("users")
      .document(id)
      .updateData({"twitter": twitter});
  main.prefs.put("twitter", twitter);
}

Future setUserIG(String ig, String id) async {
  await databaseReference
      .collection("users")
      .document(id)
      .updateData({"instagram": ig});
  main.prefs.put("instagram", ig);
}
