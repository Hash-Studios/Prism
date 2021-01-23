import 'package:Prism/routes/router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:Prism/data/informatics/dataManager.dart';

final Firestore databaseReference = Firestore.instance;
List prismWalls;
List subPrismWalls;
List sortedData;
List subSortedData;
List wallsDataL;
Map wall;
int page = 1;
int pageTrending = 1;
Future<List> getPrismWalls() async {
  if (navStack.last == "Home") {
    final box = Hive.box('wallpapers');
    if ((box.get('wallpapers') == null) ||
        (box.get('wallpapers').toString() == "[]") ||
        (box.get('date') !=
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ))) {
      debugPrint("Refetching whole collection");
      prismWalls = [];
      subPrismWalls = [];
      await databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .orderBy("createdAt", descending: true)
          .getDocuments()
          .then((value) {
        prismWalls = [];
        for (final f in value.documents) {
          Map<String, dynamic> map;
          map = f.data;
          map['createdAt'] = map['createdAt'].toString();
          prismWalls.add(map);
        }
        box.delete('wallpapers');
        if (prismWalls != []) {
          box.put('wallpapers', prismWalls);
          debugPrint("Wallpapers saved");
          box.put(
            'date',
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ),
          );
          debugPrint(prismWalls.length.toString());
          subPrismWalls = box.get('wallpapers').sublist(0, 24) as List;
        } else {
          debugPrint("Not connected to Internet");
          subPrismWalls = [];
        }
      }).catchError((e) {
        debugPrint(e.toString());
        debugPrint("data done with error");
      });
    } else {
      debugPrint("Community : Data Fetched from cache");
      prismWalls = [];
      subPrismWalls = [];
      prismWalls = box.get('wallpapers') as List;
      subPrismWalls = prismWalls.sublist(0, 24);
    }
  } else {
    debugPrint("Refresh blocked");
  }
  return subPrismWalls;
}

List seeMorePrism() {
  final int len = prismWalls.length;
  final double pages = len / 24;
  debugPrint(len.toString());
  debugPrint(pages.toString());
  debugPrint(page.toString());
  if (page < pages.floor()) {
    subPrismWalls.addAll(
        prismWalls.sublist(subPrismWalls.length, subPrismWalls.length + 24));
    page += 1;
  } else {
    subPrismWalls.addAll(prismWalls.sublist(subPrismWalls.length));
  }
  return subPrismWalls;
}

Future<Map> getDataByID(String id) async {
  wall = null;
  await databaseReference.collection("walls").getDocuments().then((value) {
    for (final element in value.documents) {
      if (element.data["id"] == id) {
        wall = element.data;
      }
    }
    return wall;
  });
}

Future<List> getTrendingWalls() async {
  await getPrismWalls();
  final List walls = prismWalls;
  final Map viewData = await getMapFromGitHub();
  final Map wallsData = viewData["wallpapers"] as Map;
  wallsDataL = [];
  sortedData = [];
  wallsData.forEach((key, value) {
    wallsDataL.add({key: value["views"]});
  });
  wallsDataL.sort((b, a) {
    return int.parse(a.values.toList()[0].toString())
        .compareTo(int.parse(b.values.toList()[0].toString()));
  });
  wallsDataL.forEach((wallData) {
    walls.forEach((element) {
      if (element["id"] == wallData.keys.toList()[0]) {
        sortedData.add(element);
      }
    });
  });
  subSortedData = sortedData.sublist(0, 24);
  return subSortedData;
}

List seeMoreTrending() {
  final int len = sortedData.length;
  final double pages = len / 24;
  debugPrint(len.toString());
  debugPrint(pages.toString());
  debugPrint(pageTrending.toString());
  if (pageTrending < pages.floor()) {
    subSortedData.addAll(
        sortedData.sublist(subSortedData.length, subSortedData.length + 24));
    pageTrending += 1;
  } else {
    subSortedData.addAll(sortedData.sublist(subSortedData.length));
  }
  return subSortedData;
}
