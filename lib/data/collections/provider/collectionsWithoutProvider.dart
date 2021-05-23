import 'package:Prism/routes/router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
List? collections;

Future<List?> getCollections() async {
  if (navStack.last == "Home") {
    debugPrint("Fetching collections!");
    collections = [];
    await databaseReference
        .collection("collections")
        .orderBy("lastEditTime", descending: true)
        .get()
        .then((value) {
      for (final doc in value.docs) {
        collections!.add(doc.data());
      }
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
  } else {
    debugPrint("Refresh blocked");
  }
  return collections;
}
