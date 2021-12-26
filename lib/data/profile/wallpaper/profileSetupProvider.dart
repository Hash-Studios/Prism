import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProfileSetupProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot>? profileSetups;

  Future<void> getProfileSetups() async {
    logger.d("Fetching first 8 profile setups");
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
    logger.d("Fetching more profile setups");
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
