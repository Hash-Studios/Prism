import 'dart:math';
import 'package:Prism/routes/router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

final Firestore databaseReference = Firestore.instance;
List wallpapersForCollections;
Set collectionNames;
Map collections;
Map wall;
Future<Map> getCollections() async {
  if (navStack.last == "Home") {
    final box = Hive.box('collections');
    // debugPrint(box.get('collections').toString());
    if ((box.get('date') !=
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            )) ||
        (box.get('collections') == null) ||
        (box.get('collections').toString() == "[]")) {
      wallpapersForCollections = [];
      collectionNames = {};
      collections = {};
      await databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .orderBy("createdAt", descending: true)
          .getDocuments()
          .then((value) {
        wallpapersForCollections = [];
        collectionNames = {};
        collections = {};
        debugPrint("Data Fetched");
        for (final DocumentSnapshot f in value.documents) {
          Map<String, dynamic> map;
          map = f.data;
          map['createdAt'] = map['createdAt'].toString();
          if (map['collections'] != null) wallpapersForCollections.add(map);
        }
        debugPrint("Data added to list");
        for (final wall in wallpapersForCollections) {
          for (final collectionName in wall['collections']) {
            if (!collectionNames.contains(collectionName)) {
              collectionNames.add(collectionName);
            }
          }
        }

        final r = Random();
        List randomList;
        randomList = [];
        var count = 0;
        for (var i = 0; i < 10; i++) {
          randomList.add(r.nextInt(wallpapersForCollections.length));
        }
        for (final wall in wallpapersForCollections) {
          for (final collectionName in wall['collections']) {
            if (!collections.containsKey(collectionName)) {
              collections[collectionName] = [];
              collections[collectionName].add(wall);
            } else {
              collections[collectionName].add(wall);
            }
            if (count == 0) {
              collections["random"] = [];
              collectionNames.add("random");
            }

            if (randomList.contains(count)) {
              collections["random"].add(wall);
            }
            count++;
          }
        }
        debugPrint("Data grouped");
        debugPrint(collectionNames.toString());

        box.delete('Collections');
        if (collections != {}) {
          box.put('collections', wallpapersForCollections);
          debugPrint("Collections saved");
          box.put(
            'date',
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ),
          );
          debugPrint(collectionNames.length.toString());
        } else {
          debugPrint("Not connected to Internet");
          collectionNames = {};
          collections = {};
        }
      }).catchError((e) {
        debugPrint(e.toString());
        debugPrint("data done with error");
      });
    } else {
      debugPrint("Collections : Data Fetched from cache");
      wallpapersForCollections = [];
      collectionNames = {};
      collections = {};
      wallpapersForCollections = box.get('collections') as List;
      for (final wall in wallpapersForCollections) {
        for (final collectionName in wall['collections']) {
          if (!collectionNames.contains(collectionName)) {
            collectionNames.add(collectionName);
          }
        }
      }

      final r = Random();
      List randomList;
      randomList = [];
      var count = 0;
      for (var i = 0; i < 10; i++) {
        randomList.add(r.nextInt(wallpapersForCollections.length));
      }
      for (final wall in wallpapersForCollections) {
        for (final collectionName in wall['collections']) {
          if (!collections.containsKey(collectionName)) {
            collections[collectionName] = [];
            collections[collectionName].add(wall);
          } else {
            collections[collectionName].add(wall);
          }
          if (count == 0) {
            collections["random"] = [];
            collectionNames.add("random");
          }

          if (randomList.contains(count)) {
            collections["random"].add(wall);
          }
          count++;
        }
      }
      debugPrint(collectionNames.length.toString());
    }
  } else {
    debugPrint("Refresh blocked");
  }
  return collections;
}
