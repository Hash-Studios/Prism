import 'package:Prism/data/links/model/linksModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
List? userProfileWalls;
List? userProfileSetups;
int len = 0;
int len2 = 0;
Future<List?> getuserProfileWalls(String? email) async {
  userProfileWalls = [];
  await databaseReference
      .collection("walls")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("createdAt", descending: true)
      .get()
      .then((value) {
    userProfileWalls = [];
    for (final f in value.docs) {
      userProfileWalls!.add(f.data());
    }
    len = userProfileWalls!.length;
    debugPrint(len.toString());
  }).catchError((e) {
    debugPrint(e.toString());
    debugPrint("data done with error");
  });
  return userProfileWalls;
}

Future<List?> getUserProfileSetups(String? email) async {
  userProfileSetups = [];
  await databaseReference
      .collection("setups")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("created_at", descending: true)
      .get()
      .then((value) {
    userProfileSetups = [];
    for (final f in value.docs) {
      userProfileSetups!.add(f.data);
    }
    len2 = userProfileSetups!.length;
    debugPrint(len.toString());
  }).catchError((e) {
    debugPrint(e.toString());
    debugPrint("data done with error");
  });
  return userProfileSetups;
}

Future<int> getProfileWallsLength(String? email) async {
  var tempList = [];
  await databaseReference
      .collection("walls")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("createdAt", descending: true)
      .get()
      .then((value) {
    tempList = [];
    value.docs.forEach((f) {
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

Future<int> getProfileSetupsLength(String? email) async {
  var tempList = [];
  await databaseReference
      .collection("setups")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("created_at", descending: true)
      .get()
      .then((value) {
    tempList = [];
    value.docs.forEach((f) {
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

// Future setUserTwitter(String twitter, String id) async {
//   await databaseReference
//       .collection("users")
//       .document(id)
//       .updateData({"twitter": twitter});
//   main.prefs.put("twitter", twitter);
// }

// Future setUserIG(String ig, String id) async {
//   await databaseReference
//       .collection("users")
//       .document(id)
//       .updateData({"instagram": ig});
//   main.prefs.put("instagram", ig);
// }

Future setUserLinks(List<LinksModel> linklist, String id) async {
  final Map updateLink = {};
  linklist.forEach((element) {
    updateLink[element.name] = element.link;
  });
  await databaseReference
      .collection("users")
      .doc(id)
      .update({"links": updateLink});
}
