import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/main.dart' as main;

final Firestore databaseReference = Firestore.instance;
Stream<List<DocumentSnapshot>> getFollowingFeed() async* {
  List following;
  final Stream<QuerySnapshot> _stream = databaseReference
      .collection("walls")
      .where("review", isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots();
  await databaseReference
      .collection("users")
      .where("email", isEqualTo: main.prefs.get('email'))
      .getDocuments()
      .then((value) {
    following = value.documents[0].data["following"] as List ?? [];
  });
  await for (final chunk in _stream) {
    final List<DocumentSnapshot> docs = chunk.documents;
    List<DocumentSnapshot> output = [];
    for (final doc in docs) {
      if (following.contains(doc.data["email"])) {
        output.add(doc);
      }
    }
    yield output;
  }
}
