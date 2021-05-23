import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;

class ProfileWallProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot>? profileWalls;

  Future<void> getProfileWalls() async {
    debugPrint("Fetching first 12 profile walls");
    profileWalls = [];
    await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: globals.prismUser.email)
        .orderBy("createdAt", descending: true)
        .limit(12)
        .get()
        .then((value) {
      profileWalls = value.docs;
    });
    notifyListeners();
  }

  Future<void> seeMoreProfileWalls() async {
    debugPrint("Fetching more profile walls");
    await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: globals.prismUser.email)
        .orderBy("createdAt", descending: true)
        .startAfterDocument(profileWalls![profileWalls!.length - 1])
        .limit(12)
        .get()
        .then((value) {
      for (final doc in value.docs) {
        profileWalls!.add(doc);
      }
    });
    notifyListeners();
  }
}
