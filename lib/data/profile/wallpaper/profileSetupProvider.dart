import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;

class ProfileSetupProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot>? profileSetups;

  Future<void> getProfileSetups() async {
    debugPrint("Fetching first 8 profile setups");
    profileSetups = [];
    await databaseReference
        .collection("setups")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: globals.prismUser.email)
        .orderBy("created_at", descending: true)
        .limit(8)
        .get()
        .then((value) {
      profileSetups = value.docs;
    });
    notifyListeners();
  }

  Future<void> seeMoreProfileSetups() async {
    debugPrint("Fetching more profile setups");
    await databaseReference
        .collection("setups")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: globals.prismUser.email)
        .orderBy("created_at", descending: true)
        .startAfterDocument(profileSetups![profileSetups!.length - 1])
        .limit(8)
        .get()
        .then((value) {
      for (final doc in value.docs) {
        profileSetups!.add(doc);
      }
    });
    notifyListeners();
  }
}
