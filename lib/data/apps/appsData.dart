import 'package:Prism/logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;

Future<List> getIcons() async {
  logger.i("Fethcing icons");
  final value = await databaseReference.collection("apps").doc('icons').get();
  logger.d(
      "Fetched ${(value.data()!["data"] as Map).values.toList().length} icons");
  final Box box = Hive.box('appsCache');
  box.put('icons', value.data()!["data"] as Map);
  logger.i("Saved icons to cache");
  return (box.get('icons') as Map).values.toList();
}
