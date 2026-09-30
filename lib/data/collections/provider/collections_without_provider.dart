import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';

const int _pageSize = 24;

List<Map<String, dynamic>> collections = <Map<String, dynamic>>[];
List<Map<String, dynamic>> anyCollectionWalls = <Map<String, dynamic>>[];
bool collectionHasMore = true;
String? _lastCollectionCursorDocId;
String? _currentCollectionName;

Future<void> getCollections() async {
  collections = <Map<String, dynamic>>[];
  collections = await firestoreClient.query<Map<String, dynamic>>(
    const FirestoreQuerySpec(
      collection: FirebaseCollections.collections,
      sourceTag: 'collections.getCollections',
      orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'lastEditTime', descending: true)],
      cachePolicy: FirestoreCachePolicy.memoryFirst,
      dedupeWindowMs: 30000,
    ),
    (data, _) => data,
  );
}

Future<void> getCollectionWithName(String name) async {
  _currentCollectionName = name;
  anyCollectionWalls = <Map<String, dynamic>>[];
  _lastCollectionCursorDocId = null;
  collectionHasMore = true;
  await _loadCollectionPage(sourceTag: 'collections.getCollectionWithName');
}

Future<void> seeMoreCollectionWithName() async {
  final String? cursor = _lastCollectionCursorDocId;
  if (!collectionHasMore || cursor == null || cursor.isEmpty) {
    collectionHasMore = false;
    return;
  }
  await _loadCollectionPage(sourceTag: 'collections.seeMoreCollectionWithName', startAfterDocId: cursor);
}

Future<void> _loadCollectionPage({required String sourceTag, String? startAfterDocId}) async {
  final rows = await firestoreClient.query<({String docId, Map<String, dynamic> data})>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: sourceTag,
      filters: <FirestoreFilter>[
        const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        FirestoreFilter(field: 'collections', op: FirestoreFilterOp.arrayContains, value: _currentCollectionName),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      startAfterDocId: startAfterDocId,
      limit: _pageSize,
      dedupeWindowMs: 1000,
    ),
    (data, docId) => (docId: docId, data: data),
  );
  collectionHasMore = rows.length == _pageSize;
  if (rows.isNotEmpty) {
    _lastCollectionCursorDocId = rows.last.docId;
  }
  final Set<String> blocked = getIt<UserBlockRepository>().cachedBlockedCreatorEmails;
  anyCollectionWalls.addAll(
    rows
        .map((row) => row.data)
        .where((wall) => !BlockedCreatorsFilter.hidesCreatorEmail(wall['email']?.toString(), blocked)),
  );
}
