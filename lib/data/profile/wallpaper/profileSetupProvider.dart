import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;

class ProfileSetupProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List? profileSetups;
  int len = 0;
  Future<List?> getProfileSetups() async {
    profileSetups = [];
    Query db;
    if (globals.prismUser.premium == true) {
      db = databaseReference
          .collection("setups")
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("created_at", descending: true);
    } else {
      db = databaseReference
          .collection("setups")
          .where('review', isEqualTo: true)
          .where('email', isEqualTo: globals.prismUser.email)
          .orderBy("created_at", descending: true);
    }
    await db.get().then((value) {
      profileSetups = [];
      for (final f in value.docs) {
        profileSetups!.add(f.data());
      }
      len = profileSetups!.length;
      debugPrint(len.toString());
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
    return profileSetups;
  }
}
