import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/data/offline/offline_snapshot_codec.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';

const int _pageSize = 24;
const Duration _offlineQueryTimeout = Duration(seconds: 2);

List<Map<String, dynamic>> collections = <Map<String, dynamic>>[];
List<Map<String, dynamic>> anyCollectionWalls = <Map<String, dynamic>>[];
bool collectionHasMore = true;
String? _lastCollectionCursorDocId;
String? _currentCollectionName;
FeedCacheLocalDataSource? _fallbackCache;

FeedCacheLocalDataSource get _feedCacheLocal => getIt.isRegistered<FeedCacheLocalDataSource>()
    ? getIt<FeedCacheLocalDataSource>()
    : _fallbackCache ??= FeedCacheLocalDataSource();

Future<void> getCollections() async {
  final List<Map<String, dynamic>> cached = await _readCollectionIndex();
  if (cached.isNotEmpty) collections = cached;
  try {
    final Future<List<Map<String, dynamic>>> request = firestoreClient.query<Map<String, dynamic>>(
      const FirestoreQuerySpec(
        collection: FirebaseCollections.collections,
        sourceTag: 'collections.getCollections',
        orderBy: <FirestoreOrderBy>[FirestoreOrderBy(field: 'lastEditTime', descending: true)],
        cachePolicy: FirestoreCachePolicy.memoryFirst,
        dedupeWindowMs: 30000,
      ),
      (data, _) => data,
    );
    final List<Map<String, dynamic>> fresh = cached.isEmpty
        ? await request
        : await request.timeout(_offlineQueryTimeout);
    if (fresh.isNotEmpty || cached.isEmpty) collections = fresh;
    try {
      await _writeCollectionIndex(collections);
    } catch (_) {}
  } catch (_) {
    if (collections.isEmpty) rethrow;
  }
}

Future<void> getCollectionWithName(String name) async {
  _currentCollectionName = name;
  final CachedCollectionWalls? cached = await _readCollectionWalls(name);
  if (cached == null) {
    anyCollectionWalls = <Map<String, dynamic>>[];
    _lastCollectionCursorDocId = null;
    collectionHasMore = true;
  } else {
    anyCollectionWalls = await _filterBlockedWalls(cached.items);
    _lastCollectionCursorDocId = cached.lastDocId;
    collectionHasMore = cached.hasMore;
  }
  await _loadCollectionPage(sourceTag: 'collections.getCollectionWithName', replace: true);
}

/// Reloads the open collection. The walls on screen stay if the reload fails.
Future<void> refreshCollectionWithName() async {
  if (_currentCollectionName == null) return;
  await _loadCollectionPage(sourceTag: 'collections.refreshCollectionWithName', replace: true);
}

Future<void> seeMoreCollectionWithName() async {
  final String? cursor = _lastCollectionCursorDocId;
  if (!collectionHasMore || cursor == null || cursor.isEmpty) {
    collectionHasMore = false;
    return;
  }
  await _loadCollectionPage(sourceTag: 'collections.seeMoreCollectionWithName', startAfterDocId: cursor);
}

Future<void> _loadCollectionPage({required String sourceTag, String? startAfterDocId, bool replace = false}) async {
  final String? name = _currentCollectionName;
  final Future<List<({String docId, Map<String, dynamic> data})>> request = firestoreClient
      .query<({String docId, Map<String, dynamic> data})>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: sourceTag,
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'collections', op: FirestoreFilterOp.arrayContains, value: name),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          startAfterDocId: startAfterDocId,
          limit: _pageSize,
          dedupeWindowMs: 1000,
        ),
        (data, docId) => (docId: docId, data: data),
      );
  late final List<({String docId, Map<String, dynamic> data})> rows;
  try {
    rows = anyCollectionWalls.isEmpty ? await request : await request.timeout(_offlineQueryTimeout);
  } catch (_) {
    if (anyCollectionWalls.isNotEmpty) return;
    rethrow;
  }
  // The user opened another collection while this page loaded.
  if (name != _currentCollectionName) return;
  if (replace && rows.isNotEmpty) {
    anyCollectionWalls = <Map<String, dynamic>>[];
    _lastCollectionCursorDocId = null;
  }
  collectionHasMore = rows.length == _pageSize;
  if (rows.isNotEmpty) {
    _lastCollectionCursorDocId = rows.last.docId;
  }
  final List<Map<String, dynamic>> pageItems = await _filterBlockedWalls(
    rows.map((row) => row.data).toList(growable: false),
  );
  anyCollectionWalls.addAll(pageItems);
  try {
    await _writeCollectionWalls(name, preserveLastItemsCount: pageItems.length);
  } catch (_) {}
}

Future<List<Map<String, dynamic>>> _readCollectionIndex() async {
  try {
    final FeedSnapshot? snapshot = await _feedCacheLocal.read(source: 'collections', scope: 'index');
    return OfflineSnapshotCodec.decodeCollectionIndex(snapshot);
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

Future<void> _writeCollectionIndex(List<Map<String, dynamic>> items) async {
  await _feedCacheLocal.write(
    source: 'collections',
    scope: 'index',
    ttlHours: 24,
    payload: OfflineSnapshotCodec.encodeCollectionIndex(items),
  );
}

Future<CachedCollectionWalls?> _readCollectionWalls(String name) async {
  try {
    final FeedSnapshot? snapshot = await _feedCacheLocal.read(source: 'collections', scope: 'walls.$name');
    return OfflineSnapshotCodec.decodeCollectionWalls(snapshot);
  } catch (_) {
    return null;
  }
}

Future<List<Map<String, dynamic>>> _filterBlockedWalls(List<Map<String, dynamic>> walls) async {
  if (!getIt.isRegistered<UserBlockRepository>()) return walls;
  final Set<String> blocked = await getIt<UserBlockRepository>().getBlockedCreatorEmails(waitForInitialLoad: true);
  return walls
      .where((wall) => !BlockedCreatorsFilter.hidesCreatorEmail(wall['email']?.toString(), blocked))
      .toList(growable: false);
}

Future<void> _writeCollectionWalls(String? name, {required int preserveLastItemsCount}) async {
  if (name == null) return;
  final Map<String, Map<String, dynamic>> unique = <String, Map<String, dynamic>>{
    for (final Map<String, dynamic> wall in anyCollectionWalls)
      (wall['id']?.toString().trim().isNotEmpty == true ? wall['id'].toString() : wall['wallpaper_url'].toString()):
          wall,
  };
  final List<Map<String, dynamic>> items = unique.values.toList(growable: true);
  await _feedCacheLocal.write(
    source: 'collections',
    scope: 'walls.$name',
    ttlHours: 24,
    payload: OfflineSnapshotCodec.encodeCollectionWalls(
      items: items,
      lastDocId: _lastCollectionCursorDocId,
      hasMore: collectionHasMore,
      preserveLastItemsCount: preserveLastItemsCount,
    ),
  );
}
