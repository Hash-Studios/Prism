import 'package:Prism/data/links/model/linksModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot>? userProfileWalls;
  List<QueryDocumentSnapshot>? userProfileSetups;

  Future<void> getuserProfileWalls(String? email) async {
    debugPrint("Fetching first 12 profile walls");
    userProfileWalls = [];
    await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: email)
        .orderBy("createdAt", descending: true)
        .limit(12)
        .get()
        .then((value) {
      userProfileWalls = value.docs;
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
    notifyListeners();
  }

  Future<void> seeMoreUserProfileWalls(String? email) async {
    debugPrint("Fetching more profile walls");
    await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: email)
        .orderBy("createdAt", descending: true)
        .startAfterDocument(userProfileWalls![userProfileWalls!.length - 1])
        .limit(12)
        .get()
        .then((value) {
      for (final doc in value.docs) {
        userProfileWalls!.add(doc);
      }
    });
    notifyListeners();
  }

  Future<void> getUserProfileSetups(String? email) async {
    debugPrint("Fetching first 8 profile setups");
    userProfileSetups = [];
    await databaseReference
        .collection("setups")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: email)
        .orderBy("created_at", descending: true)
        .limit(8)
        .get()
        .then((value) {
      userProfileSetups = value.docs;
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
    notifyListeners();
  }

  Future<void> seeMoreUserProfileSetups(String? email) async {
    debugPrint("Fetching more profile walls");
    await databaseReference
        .collection("setups")
        .where('review', isEqualTo: true)
        .where('email', isEqualTo: email)
        .orderBy("created_at", descending: true)
        .startAfterDocument(userProfileSetups![userProfileSetups!.length - 1])
        .limit(8)
        .get()
        .then((value) {
      for (final doc in value.docs) {
        userProfileSetups!.add(doc);
      }
    });
    notifyListeners();
  }
}

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
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
