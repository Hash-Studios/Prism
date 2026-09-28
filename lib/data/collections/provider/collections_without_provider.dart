import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';

List<Map<String, dynamic>> _dropBlockedCreators(List<Map<String, dynamic>> rows) {
  final Set<String> blocked = getIt<UserBlockRepository>().cachedBlockedCreatorEmails;
  if (blocked.isEmpty) {
    return rows;
  }
  return rows
      .where((row) => !BlockedCreatorsFilter.hidesCreatorEmail(row['email']?.toString(), blocked))
      .toList(growable: false);
}

List? collections;
List<Map<String, dynamic>>? anyCollectionWalls;
String? _lastCollectionCursorDocId;
String? currentCollectionName;
bool collectionHasMore = true;

Future<List?> getCollections() async {
  logger.d("Fetching collections!");
  collections = [];
  await firestoreClient
      .query<Map<String, dynamic>>(
        const FirestoreQuerySpec(
          collection: FirebaseCollections.collections,
          sourceTag: 'collections.getCollections',
          orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'lastEditTime', descending: true)],
          cachePolicy: FirestoreCachePolicy.memoryFirst,
          dedupeWindowMs: 30000,
        ),
        (data, _) => data,
      )
      .then((value) {
        for (final doc in value) {
          collections!.add(doc);
        }
      })
      .catchError((e) {
        logger.d(e.toString());
        logger.d("data done with error");
      });
  return collections;
}

Future<bool> getCollectionWithName(String name) async {
  logger.d("Fetching $name collection's first 24 walls");
  currentCollectionName = name;
  anyCollectionWalls = [];
  _lastCollectionCursorDocId = null;
  collectionHasMore = true;
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
      dedupeWindowMs: 1000,
    ),
    (data, docId) => <String, dynamic>{...data, '__docId': docId},
  );
  collectionHasMore = rows.length == 24;
  if (rows.isNotEmpty) {
    _lastCollectionCursorDocId = rows.last['__docId']?.toString();
    for (final row in rows) {
      row.remove('__docId');
    }
  }
  anyCollectionWalls = _dropBlockedCreators(rows);
  return true;
}

Future<bool> seeMoreCollectionWithName() async {
  logger.d("Fetching $currentCollectionName collection's more walls");
  if (!collectionHasMore || _lastCollectionCursorDocId == null || _lastCollectionCursorDocId!.isEmpty) {
    collectionHasMore = false;
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
      dedupeWindowMs: 1000,
    ),
    (data, docId) => <String, dynamic>{...data, '__docId': docId},
  );
  collectionHasMore = rows.length == 24;
  if (rows.isNotEmpty) {
    _lastCollectionCursorDocId = rows.last['__docId']?.toString();
  }
  for (final row in rows) {
    row.remove('__docId');
  }
  anyCollectionWalls!.addAll(_dropBlockedCreators(rows));
  return true;
}
