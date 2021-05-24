import 'dart:async';

import 'package:Prism/routes/router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
List? prismWalls;
List<QueryDocumentSnapshot>? prismWallsDocSnaps;
List? subPrismWalls;
List? sortedData;
List? subSortedData;
late List wallsDataL;
Map wall = {};
Future<List?> getPrismWalls() async {
  if (navStack.last == "Home") {
    debugPrint("Fetching first 24 walls!");
    prismWalls = [];
    subPrismWalls = [];
    await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .orderBy("createdAt", descending: true)
        .limit(24)
        .get()
        .then((value) {
      prismWalls = [];
      prismWallsDocSnaps = value.docs;
      for (final f in value.docs) {
        Map<String, dynamic> map;
        map = f.data();
        map['createdAt'] = map['createdAt'].toString();
        prismWalls!.add(map);
      }
      if (prismWalls != []) {
        debugPrint("${prismWalls!.length} walls fetched!");
        subPrismWalls = prismWalls;
      } else {
        debugPrint("Not connected to Internet");
        subPrismWalls = [];
      }
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("data done with error");
    });
  } else {
    debugPrint("Refresh blocked");
  }
  return subPrismWalls;
}

Future<List?> seeMorePrism() async {
  debugPrint("Fetching more walls!");
  await databaseReference
      .collection("walls")
      .where('review', isEqualTo: true)
      .orderBy("createdAt", descending: true)
      .startAfterDocument(prismWallsDocSnaps![prismWallsDocSnaps!.length - 1])
      .limit(24)
      .get()
      .then((value) {
    for (final doc in value.docs) {
      prismWallsDocSnaps!.add(doc);
    }
    for (final f in value.docs) {
      Map<String, dynamic> map;
      map = f.data();
      map['createdAt'] = map['createdAt'].toString();
      prismWalls!.add(map);
    }
    if (prismWalls != []) {
      final int len = prismWalls!.length;
      final double pageNumber = len / 24;
      debugPrint("${value.docs.length} walls fetched!");
      debugPrint("$len total walls fetched!");
      debugPrint("PageNumber: $pageNumber");
      subPrismWalls!.addAll(prismWalls!.sublist(subPrismWalls!.length));
    } else {
      debugPrint("Not connected to Internet");
    }
  });
  return subPrismWalls;
}

Future<Map> getDataByID(String? id) async {
  wall = {};
  await databaseReference
      .collection("walls")
      .where('id', isEqualTo: id)
      .get()
      .then((value) {
    for (final element in value.docs) {
      if (element.data()["id"] == id) {
        wall = element.data();
      }
    }
    return wall;
  });
  return wall;
}
