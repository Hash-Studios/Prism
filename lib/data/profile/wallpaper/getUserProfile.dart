import 'package:Prism/data/links/model/linksModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;

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
      userProfileSetups!.add(f.data());
    }
    len2 = userProfileSetups!.length;
    debugPrint(len.toString());
  }).catchError((e) {
    debugPrint(e.toString());
    debugPrint("data done with error");
  });
  return userProfileSetups;
}

Stream<QuerySnapshot> getUserProfile(String email) {
  return databaseReference
      .collection('users')
      .where('email', isEqualTo: email)
      .snapshots();
}

Future<void> follow(String email, String id) async {
  await databaseReference.collection('users').doc(globals.prismUser.id).update({
    'following': FieldValue.arrayUnion([email]),
  });
  await databaseReference.collection('users').doc(id).update({
    'followers': FieldValue.arrayUnion([globals.prismUser.email]),
  });
}

Future<void> unfollow(String email, String id) async {
  await databaseReference.collection('users').doc(globals.prismUser.id).update({
    'following': FieldValue.arrayRemove([email]),
  });
  await databaseReference.collection('users').doc(id).update({
    'followers': FieldValue.arrayRemove([globals.prismUser.email]),
  });
}

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
