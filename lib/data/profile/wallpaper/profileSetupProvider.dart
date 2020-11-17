import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;

class ProfileSetupProvider extends ChangeNotifier {
  final Firestore databaseReference = Firestore.instance;
  List profileSetups;
  int len = 0;
  Future<List> getProfileSetups() async {
    profileSetups = [];
    Query db;
    if (main.prefs.get('premium') == true) {
      db = databaseReference
          .collection("setups")
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("created_at", descending: true);
    } else {
      db = databaseReference
          .collection("setups")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: main.prefs.get('email'))
          .orderBy("created_at", descending: true);
    }
    await db.getDocuments().then((value) {
      profileSetups = [];
      for (final f in value.documents) {
        profileSetups.add(f.data);
      }
      len = profileSetups.length;
      debugPrint(len.toString());
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
    return profileSetups;
  }
}
