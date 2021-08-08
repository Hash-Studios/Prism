import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/auth/userOldModel.dart';
import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;

class UserProfileProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot>? userProfileWalls;
  List<QueryDocumentSnapshot>? userProfileSetups;

  Future<void> getuserProfileWalls(String? email) async {
    logger.d("Fetching first 12 profile walls");
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
      logger.d(e.toString());
      logger.d("data done with error");
    });
    notifyListeners();
  }

  Future<void> seeMoreUserProfileWalls(String? email) async {
    logger.d("Fetching more profile walls");
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
    logger.d("Fetching first 8 profile setups");
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
      logger.d(e.toString());
      logger.d("data done with error");
    });
    notifyListeners();
  }

  Future<void> seeMoreUserProfileSetups(String? email) async {
    logger.d("Fetching more profile walls");
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
      .collection(USER_NEW_COLLECTION)
      .where('email', isEqualTo: email)
      .snapshots()
      .asyncMap((event) {
    if (event.docs.isEmpty) {
      return databaseReference
          .collection(USER_OLD_COLLECTION)
          .where('email', isEqualTo: email)
          .get();
    } else {
      return event;
    }
  });
}

Future<void> follow(String email, String id) async {
  await databaseReference
      .collection(USER_NEW_COLLECTION)
      .doc(globals.prismUser.id)
      .update({
    'following': FieldValue.arrayUnion([email]),
  });
  await databaseReference.collection(USER_NEW_COLLECTION).doc(id).update({
    'followers': FieldValue.arrayUnion([globals.prismUser.email]),
  });
}

Future<void> unfollow(String email, String id) async {
  await databaseReference
      .collection(USER_NEW_COLLECTION)
      .doc(globals.prismUser.id)
      .update({
    'following': FieldValue.arrayRemove([email]),
  });
  await databaseReference.collection(USER_NEW_COLLECTION).doc(id).update({
    'followers': FieldValue.arrayRemove([globals.prismUser.email]),
  });
}

// Future<void> copyUser() async {
//   await databaseReference
//       .collection(USER_OLD_COLLECTION)
//       .doc("3KVCKlBiY7m6dDfyhRCj")
//       .get()
//       .then((value) async {
//     final user = PrismUsersV2.fromDocumentSnapshotWithoutUser(value);
//     await FirebaseFirestore.instance
//         .collection(USER_NEW_COLLECTION)
//         .doc("3KVCKlBiY7m6dDfyhRCj")
//         .set(user.toJson());
//   });
// }

Future setUserLinks(List<LinksModel> linklist, String id) async {
  final Map updateLink = {};
  linklist.forEach((element) {
    updateLink[element.name] = element.link;
  });
  await databaseReference
      .collection(USER_NEW_COLLECTION)
      .doc(id)
      .update({"links": updateLink});
}
