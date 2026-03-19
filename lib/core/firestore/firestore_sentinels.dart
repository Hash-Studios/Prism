import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSentinels {
  const FirestoreSentinels._();

  static Object arrayUnion(List<Object?> values) => FieldValue.arrayUnion(values);
  static Object arrayRemove(List<Object?> values) => FieldValue.arrayRemove(values);
}
