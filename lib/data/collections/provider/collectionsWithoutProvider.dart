import 'dart:math';
import 'package:Prism/routes/router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

final databaseReference = Firestore.instance;
List wallpapersForCollections;
Set collectionNames;
Map collections;
Map wall;
Future<Map> getCollections() async {
  if (navStack.last == "Home") {
    var box = Hive.box('collections');
    print(box.get('collections'));
    if ((box.get('date') !=
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            )) ||
        (box.get('collections') == null) ||
        (box.get('collections') == [])) {
      wallpapersForCollections = [];
      collectionNames = {};
      collections = {};
      await databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .orderBy("collections", descending: true)
          .getDocuments()
          .then((value) {
        wallpapersForCollections = [];
        collectionNames = {};
        collections = {};
        print("Data Fetched");
        value.documents.forEach((f) {
          var map = f.data;
          map['createdAt'] = map['createdAt'].toString();
          wallpapersForCollections.add(map);
        });
        print("Data added to list");
        for (var wall in wallpapersForCollections) {
          for (var collectionName in wall['collections']) {
            if (!collectionNames.contains(collectionName)) {
              collectionNames.add(collectionName);
            }
          }
        }

        var r = Random();
        var randomList = [];
        var count = 0;
        for (var i = 0; i < 10; i++) {
          randomList.add(r.nextInt(wallpapersForCollections.length));
        }
        for (var wall in wallpapersForCollections) {
          for (var collectionName in wall['collections']) {
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
        print("Data grouped");
        print(collectionNames);

        box.delete('Collections');
        if (collections != {}) {
          box.put('collections', wallpapersForCollections);
          print("Collections saved");
          box.put(
            'date',
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ),
          );
          print(collectionNames.length);
        } else {
          print("Not connected to Internet");
          collectionNames = {};
          collections = {};
        }
      }).catchError((e) {
        print(e.toString());
        print("data done with error");
      });
    } else {
      print("Collections : Data Fetched from cache");
      wallpapersForCollections = [];
      collectionNames = {};
      collections = {};
      wallpapersForCollections = box.get('collections');
      for (var wall in wallpapersForCollections) {
        for (var collectionName in wall['collections']) {
          if (!collectionNames.contains(collectionName)) {
            collectionNames.add(collectionName);
          }
        }
      }

      var r = Random();
      var randomList = [];
      var count = 0;
      for (var i = 0; i < 10; i++) {
        randomList.add(r.nextInt(wallpapersForCollections.length));
      }
      for (var wall in wallpapersForCollections) {
        for (var collectionName in wall['collections']) {
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
      print(collectionNames.length);
    }
  } else {
    print("Refresh blocked");
  }
  return collections;
}
