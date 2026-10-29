import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/data/offline/offline_snapshot_codec.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';

const int _pageSize = 24;
const Duration _offlineQueryTimeout = Duration(seconds: 2);

List<Map<String, dynamic>> collections = <Map<String, dynamic>>[];
List<Map<String, dynamic>> anyCollectionWalls = <Map<String, dynamic>>[];
bool collectionHasMore = true;
String? _lastCollectionCursorDocId;
String? _currentCollectionName;
int _indexGeneration = 0;
int _collectionGeneration = 0;
int? _activeCollectionLoadGeneration;
bool _hasCollectionSnapshot = false;
FeedCacheLocalDataSource? _fallbackCache;

FeedCacheLocalDataSource get _feedCacheLocal => getIt.isRegistered<FeedCacheLocalDataSource>()
    ? getIt<FeedCacheLocalDataSource>()
    : _fallbackCache ??= FeedCacheLocalDataSource();

Future<void> getCollections() async {
  final int generation = ++_indexGeneration;
  final List<Map<String, dynamic>>? cached = await _readCollectionIndex();
  if (generation != _indexGeneration) return;
  if (cached != null) collections = cached;
  final bool hasSnapshot = cached != null || collections.isNotEmpty;
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
    final List<Map<String, dynamic>> fresh = hasSnapshot ? await request.timeout(_offlineQueryTimeout) : await request;
    if (generation != _indexGeneration) return;
    collections = fresh;
    try {
      await _writeCollectionIndex(fresh);
    } catch (_) {}
  } catch (_) {
    if (generation != _indexGeneration) return;
    if (!hasSnapshot) rethrow;
  }
}

Future<void> getCollectionWithName(String name) {
  final int generation = ++_collectionGeneration;
  _currentCollectionName = name;
  return _runCollectionLoad(generation, () async {
    final CachedCollectionWalls? cached = await _readCollectionWalls(name);
    if (generation != _collectionGeneration) return;
    final List<Map<String, dynamic>> items = cached == null
        ? <Map<String, dynamic>>[]
        : await _filterBlockedWalls(cached.items);
    if (generation != _collectionGeneration) return;
    _hasCollectionSnapshot = cached != null;
    anyCollectionWalls = items;
    _lastCollectionCursorDocId = cached?.lastDocId;
    collectionHasMore = cached?.hasMore ?? true;
    await _loadCollectionPage(
      name: name,
      generation: generation,
      sourceTag: 'collections.getCollectionWithName',
      replace: true,
    );
  });
}

/// Reloads the open collection. The walls on screen stay if the reload fails.
Future<void> refreshCollectionWithName() async {
  final String? name = _currentCollectionName;
  if (name == null) return;
  final int generation = ++_collectionGeneration;
  await _runCollectionLoad(
    generation,
    () => _loadCollectionPage(
      name: name,
      generation: generation,
      sourceTag: 'collections.refreshCollectionWithName',
      replace: true,
    ),
  );
}

Future<void> seeMoreCollectionWithName() async {
  if (_activeCollectionLoadGeneration != null) return;
  final String? name = _currentCollectionName;
  if (name == null) return;
  final String? cursor = _lastCollectionCursorDocId;
  if (!collectionHasMore || cursor == null || cursor.isEmpty) {
    collectionHasMore = false;
    return;
  }
  final int generation = _collectionGeneration;
  await _runCollectionLoad(
    generation,
    () => _loadCollectionPage(
      name: name,
      generation: generation,
      sourceTag: 'collections.seeMoreCollectionWithName',
      startAfterDocId: cursor,
    ),
  );
}

Future<void> _runCollectionLoad(int generation, Future<void> Function() load) async {
  _activeCollectionLoadGeneration = generation;
  try {
    await load();
  } finally {
    if (_activeCollectionLoadGeneration == generation) _activeCollectionLoadGeneration = null;
  }
}

Future<void> _loadCollectionPage({
  required String name,
  required int generation,
  required String sourceTag,
  String? startAfterDocId,
  bool replace = false,
}) async {
  final List<Map<String, dynamic>> previousItems = List<Map<String, dynamic>>.of(anyCollectionWalls);
  final bool hasSnapshot = _hasCollectionSnapshot || previousItems.isNotEmpty;
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
    rows = hasSnapshot ? await request.timeout(_offlineQueryTimeout) : await request;
  } catch (_) {
    if (generation != _collectionGeneration || (hasSnapshot && replace)) return;
    rethrow;
  }
  if (generation != _collectionGeneration) return;
  final List<Map<String, dynamic>> pageItems = await _filterBlockedWalls(
    rows.map((row) => row.data).toList(growable: false),
  );
  if (generation != _collectionGeneration) return;
  final List<Map<String, dynamic>> items = <Map<String, dynamic>>[if (!replace) ...previousItems, ...pageItems];
  final String? lastDocId = rows.isNotEmpty ? rows.last.docId : (replace ? null : startAfterDocId);
  final bool hasMore = rows.length == _pageSize;
  anyCollectionWalls = items;
  _lastCollectionCursorDocId = lastDocId;
  collectionHasMore = hasMore;
  _hasCollectionSnapshot = true;
  try {
    await _writeCollectionWalls(
      name,
      items: items,
      lastDocId: lastDocId,
      hasMore: hasMore,
      preserveLastItemsCount: pageItems.length,
    );
  } catch (_) {}
}

Future<List<Map<String, dynamic>>?> _readCollectionIndex() async {
  try {
    final FeedSnapshot? snapshot = await _feedCacheLocal.read(source: 'collections', scope: 'index');
    return snapshot == null ? null : OfflineSnapshotCodec.decodeCollectionIndex(snapshot);
  } catch (_) {
    return null;
  }
}

Future<void> _writeCollectionIndex(List<Map<String, dynamic>> items) async {
  await _feedCacheLocal.write(
    source: 'collections',
    scope: 'index',
    ttlHours: 24,
    payload: toJsonMap(OfflineSnapshotCodec.encodeCollectionIndex(items)),
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
  final Set<String> blocked = await getIt<UserBlockRepository>().getBlockedCreatorUids(waitForInitialLoad: true);
  return walls
      .where((wall) => !BlockedCreatorsFilter.hidesCreatorUid(wall['creatorUid']?.toString(), blocked))
      .toList(growable: false);
}

Future<void> _writeCollectionWalls(
  String name, {
  required List<Map<String, dynamic>> items,
  required String? lastDocId,
  required bool hasMore,
  required int preserveLastItemsCount,
}) async {
  final Map<String, Map<String, dynamic>> unique = <String, Map<String, dynamic>>{
    for (final Map<String, dynamic> wall in items)
      (wall['id']?.toString().trim().isNotEmpty == true ? wall['id'].toString() : wall['wallpaper_url'].toString()):
          wall,
  };
  await _feedCacheLocal.write(
    source: 'collections',
    scope: 'walls.$name',
    ttlHours: 24,
    payload: toJsonMap(
      OfflineSnapshotCodec.encodeCollectionWalls(
        items: unique.values.toList(growable: false),
        lastDocId: lastDocId,
        hasMore: hasMore,
        preserveLastItemsCount: preserveLastItemsCount,
      ),
    ),
  );
}
