import 'dart:async';

import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
List? prismWalls;
List<QueryDocumentSnapshot>? prismWallsDocSnaps;
List? subPrismWalls;
List? sortedData;
List? subSortedData;
late List wallsDataL;
Map wall = {};
Future<List?> getPrismWalls() async {
  logger.d(
    "[PrismFeed] getPrismWalls start",
    fields: <String, Object?>{"nav": currentNavStackEntry},
  );
  if (currentNavStackEntry != "Home") {
    logger.w(
      "[PrismFeed] getPrismWalls called while nav is not Home; continuing fetch",
      fields: <String, Object?>{"nav": currentNavStackEntry},
    );
  }
  prismWalls = [];
  subPrismWalls = [];
  try {
    final QuerySnapshot<Map<String, dynamic>> value = await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .orderBy("createdAt", descending: true)
        .limit(24)
        .get();

    prismWalls = <Map<String, dynamic>>[];
    prismWallsDocSnaps = value.docs;
    for (final f in value.docs) {
      final Map<String, dynamic> map = f.data();
      map['createdAt'] = map['createdAt'].toString();
      prismWalls!.add(map);
    }

    subPrismWalls = prismWalls;
    logger.i(
      "[PrismFeed] getPrismWalls success",
      fields: <String, Object?>{
        "count": prismWalls!.length,
        "docSnaps": prismWallsDocSnaps?.length ?? 0,
      },
    );
  } catch (error, stackTrace) {
    subPrismWalls = <Map<String, dynamic>>[];
    logger.e(
      "[PrismFeed] getPrismWalls failed",
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{"nav": currentNavStackEntry},
    );
    rethrow;
  }
  return subPrismWalls;
}

Future<List?> seeMorePrism() async {
  logger.d(
    "[PrismFeed] seeMorePrism start",
    fields: <String, Object?>{
      "existing": subPrismWalls?.length ?? 0,
      "docSnaps": prismWallsDocSnaps?.length ?? 0,
    },
  );
  if (!(prismWallsDocSnaps?.isNotEmpty ?? false)) {
    logger.w("[PrismFeed] seeMorePrism skipped: no cursor snapshot available");
    return subPrismWalls ?? prismWalls ?? <dynamic>[];
  }
  prismWalls ??= <Map<String, dynamic>>[];
  subPrismWalls ??= <Map<String, dynamic>>[];
  try {
    final QuerySnapshot<Map<String, dynamic>> value = await databaseReference
        .collection("walls")
        .where('review', isEqualTo: true)
        .orderBy("createdAt", descending: true)
        .startAfterDocument(prismWallsDocSnaps![prismWallsDocSnaps!.length - 1])
        .limit(24)
        .get();
    for (final doc in value.docs) {
      prismWallsDocSnaps!.add(doc);
    }
    for (final f in value.docs) {
      final Map<String, dynamic> map = f.data();
      map['createdAt'] = map['createdAt'].toString();
      prismWalls!.add(map);
    }
    final int len = prismWalls!.length;
    final int oldLen = subPrismWalls!.length;
    if (oldLen < len) {
      subPrismWalls!.addAll(prismWalls!.sublist(oldLen));
    }
    logger.i(
      "[PrismFeed] seeMorePrism success",
      fields: <String, Object?>{
        "fetched": value.docs.length,
        "total": subPrismWalls!.length,
      },
    );
  } catch (error, stackTrace) {
    logger.e(
      "[PrismFeed] seeMorePrism failed",
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
  return subPrismWalls;
}

Future<Map> getDataByID(String? id) async {
  wall = {};
  await databaseReference.collection("walls").where('id', isEqualTo: id).get().then((value) {
    for (final element in value.docs) {
      if (element.data()["id"] == id) {
        wall = element.data();
      }
    }
    return wall;
  });
  return wall;
}
