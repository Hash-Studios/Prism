import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/logger/logger.dart';

List? collections;
List<Map<String, dynamic>>? anyCollectionWalls;
String? _lastCollectionCursorDocId;
String? currentCollectionName;

Future<List?> getCollections() async {
  if (currentNavStackEntry == "Home") {
    logger.d("Fetching collections!");
    collections = [];
    await firestoreClient
        .query<Map<String, dynamic>>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.collections,
        sourceTag: 'collections.getCollections',
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'lastEditTime', descending: true)],
      ),
      (data, _) => data,
    )
        .then((value) {
      for (final doc in value) {
        collections!.add(doc);
      }
    }).catchError((e) {
      logger.d(e.toString());
      logger.d("data done with error");
    });
  } else {
    logger.d("Refresh blocked");
  }
  return collections;
}

Future<bool> getCollectionWithName(String name) async {
  logger.d("Fetching $name collection's first 24 walls");
  currentCollectionName = name;
  anyCollectionWalls = [];
  _lastCollectionCursorDocId = null;
  final List<Map<String, dynamic>> rows = await firestoreClient.query<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'collections.getCollectionWithName',
      filters: <FirestoreFilter>[
        const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        FirestoreFilter(field: 'collections', op: FirestoreFilterOp.arrayContains, value: name),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      limit: 24,
    ),
    (data, docId) => <String, dynamic>{...data, '__docId': docId},
  );
  anyCollectionWalls = rows;
  if (rows.isNotEmpty) {
    _lastCollectionCursorDocId = rows.last['__docId']?.toString();
    for (final row in rows) {
      row.remove('__docId');
    }
  }
  return true;
}

Future<bool> seeMoreCollectionWithName() async {
  logger.d("Fetching $currentCollectionName collection's more walls");
  if (_lastCollectionCursorDocId == null || _lastCollectionCursorDocId!.isEmpty) {
    return true;
  }
  final List<Map<String, dynamic>> rows = await firestoreClient.query<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'collections.seeMoreCollectionWithName',
      filters: <FirestoreFilter>[
        const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        FirestoreFilter(field: 'collections', op: FirestoreFilterOp.arrayContains, value: currentCollectionName),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      startAfterDocId: _lastCollectionCursorDocId,
      limit: 24,
    ),
    (data, docId) => <String, dynamic>{...data, '__docId': docId},
  );
  if (rows.isNotEmpty) {
    _lastCollectionCursorDocId = rows.last['__docId']?.toString();
  }
  for (final row in rows) {
    row.remove('__docId');
    anyCollectionWalls!.add(row);
  }
  return true;
}
