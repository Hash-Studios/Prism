import 'package:cloud_firestore/cloud_firestore.dart';

final databaseReference = Firestore.instance;
List userProfileWalls;
int len = 0;
Future<List> getuserProfileWalls(String email) async {
  userProfileWalls = [];
  await databaseReference
      .collection("walls")
      .where('review', isEqualTo: true)
      .where('email', isEqualTo: email)
      .orderBy("createdAt", descending: true)
      .getDocuments()
      .then((value) {
    userProfileWalls = [];
    value.documents.forEach((f) {
      userProfileWalls.add(f.data);
    });
    len = userProfileWalls.length;
    print(len);
  }).catchError((e) {
    print(e.toString());
    print("data done with error");
  });
  return userProfileWalls;
}
