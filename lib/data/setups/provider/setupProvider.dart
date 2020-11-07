import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class SetupProvider extends ChangeNotifier {
  final Firestore databaseReference = Firestore.instance;
  List setups;
  Future<List> getDataBase() async {
    final box = Hive.box('setups');
    if ((box.get('setups') == null) ||
        (box.get('setups').toString() == "[]") ||
        (box.get('date') !=
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ))) {
      debugPrint("Refetching setups collection");
      setups = [];
      await databaseReference
          .collection("setups")
          .orderBy("created_at", descending: true)
          .where("review", isEqualTo: true)
          .getDocuments()
          .then((value) {
        for (final f in value.documents) {
          Map<String, dynamic> map;
          map = f.data;
          map['created_at'] = map['created_at'].toDate();
          setups.add(map);
        }
        box.delete('setups');
        if (setups != []) {
          box.put('setups', setups);
          debugPrint("Setups saved");
          box.put(
            'date',
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ),
          );
          box.put(
            'dateTime',
            DateTime.now().toString(),
          );
          debugPrint(setups.length.toString());
        } else {
          debugPrint("Not connected to Internet");
        }
      }).catchError((e) {
        debugPrint(e.toString());
        debugPrint("data done with error");
      });
    } else {
      debugPrint("Setups : Data Fetched from cache");
      setups = [];
      setups = box.get('setups') as List;
      debugPrint(setups.length.toString());
    }
    return setups;
  }
}

final databaseReference2 = Firestore.instance;
Map setup;
Future<Map> getSetupFromName(String name) async {
  setup = {};
  await databaseReference2
      .collection("setups")
      .where("name", isEqualTo: name)
      .getDocuments()
      .then((value) {
    value.documents.forEach((f) => setup = f.data);
    debugPrint(setup.toString());
  }).catchError((e) {
    debugPrint("data done with error");
  });
  return setup;
}
