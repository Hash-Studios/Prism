import 'dart:async';

import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/logger/logger.dart';

List? prismWalls;
List<String>? prismWallsDocSnaps;
List? subPrismWalls;
List? sortedData;
List? subSortedData;
late List wallsDataL;
Map wall = {};
bool prismHasMore = true;
Future<List?> getPrismWalls() async {
  logger.d("[PrismFeed] getPrismWalls start");
  prismWalls = [];
  subPrismWalls = [];
  prismHasMore = true;
  try {
    final List<Map<String, dynamic>> value = await firestoreClient.query<Map<String, dynamic>>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'prism.getPrismWalls',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        ],
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        limit: 24,
        dedupeWindowMs: 1000,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    prismHasMore = value.length == 24;
    prismWalls = <Map<String, dynamic>>[];
    prismWallsDocSnaps = <String>[];
    for (final f in value) {
      final Map<String, dynamic> map = <String, dynamic>{...f};
      map['createdAt'] = map['createdAt'].toString();
      prismWallsDocSnaps!.add((map['__docId'] ?? '').toString());
      map.remove('__docId');
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
    prismHasMore = false;
    return subPrismWalls ?? prismWalls ?? <dynamic>[];
  }
  prismWalls ??= <Map<String, dynamic>>[];
  subPrismWalls ??= <Map<String, dynamic>>[];
  try {
    final List<Map<String, dynamic>> value = await firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'prism.seeMorePrism',
        filters: const <FirestoreFilter>[
          FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        ],
        orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        startAfterDocId: prismWallsDocSnaps!.last,
        limit: 24,
        dedupeWindowMs: 1000,
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    prismHasMore = value.length == 24;
    for (final f in value) {
      final Map<String, dynamic> map = <String, dynamic>{...f};
      map['createdAt'] = map['createdAt'].toString();
      prismWallsDocSnaps!.add((map['__docId'] ?? '').toString());
      map.remove('__docId');
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
        "fetched": value.length,
        "total": subPrismWalls!.length,
      },
    );
  } catch (error, stackTrace) {
    prismHasMore = false;
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
  final List<Map<String, dynamic>> rows = await firestoreClient.query<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'prism.getDataById',
      filters: <FirestoreFilter>[
        FirestoreFilter(field: 'id', op: FirestoreFilterOp.isEqualTo, value: id),
      ],
      limit: 1,
    ),
    (data, _) => data,
  );
  for (final Map<String, dynamic> element in rows) {
    if (element["id"] == id) {
      wall = element;
      break;
    }
  }
  return wall;
}
