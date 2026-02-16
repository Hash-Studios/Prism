import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;

Stream<QuerySnapshot> getUserProfile(String email) {
  return databaseReference
      .collection(USER_NEW_COLLECTION)
      .where('email', isEqualTo: email)
      .snapshots()
      .asyncMap((event) {
    if (event.docs.isEmpty) {
      return databaseReference.collection(USER_OLD_COLLECTION).where('email', isEqualTo: email).get();
    } else {
      return event;
    }
  });
}

Future<void> follow(String email, String id) async {
  await databaseReference.collection(USER_NEW_COLLECTION).doc(globals.prismUser.id).update({
    'following': FieldValue.arrayUnion([email]),
  });
  await databaseReference.collection(USER_NEW_COLLECTION).doc(id).update({
    'followers': FieldValue.arrayUnion([globals.prismUser.email]),
  });
}

Future<void> unfollow(String email, String id) async {
  await databaseReference.collection(USER_NEW_COLLECTION).doc(globals.prismUser.id).update({
    'following': FieldValue.arrayRemove([email]),
  });
  await databaseReference.collection(USER_NEW_COLLECTION).doc(id).update({
    'followers': FieldValue.arrayRemove([globals.prismUser.email]),
  });
}

Future<void> setUserLinks(List<LinksModel> linklist, String id) async {
  final Map<String, dynamic> updateLink = <String, dynamic>{};
  for (final element in linklist) {
    updateLink[element.name] = element.link;
  }
  await databaseReference.collection(USER_NEW_COLLECTION).doc(id).update({'links': updateLink});
}
