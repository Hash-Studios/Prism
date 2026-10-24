import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/data/offline/offline_snapshot_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PrismWallpaperRepository)
class PrismWallpaperRepositoryImpl implements PrismWallpaperRepository {
  PrismWallpaperRepositoryImpl(this._firestoreClient, this._feedCacheLocal, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final UserBlockRepository _userBlockRepository;

  String? _lastDocId;
  bool _hasMore = true;
  int _feedGeneration = 0;
  static const int _pageSize = 24;
  static const int _feedTtlHours = 6;
  static const Duration _queryTimeout = Duration(seconds: 10);

  @override
  bool get hasMore => _hasMore;

  @override
  Future<Result<List<PrismWallpaper>>> fetchFeed({required bool refresh}) async {
    if (refresh) {
      _feedGeneration++;
      _lastDocId = null;
      _hasMore = true;
    }
    final int generation = _feedGeneration;

    try {
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
      if (generation != _feedGeneration) return Result.success(const <PrismWallpaper>[]);
      final List<_PrismRow> traversedRows = <_PrismRow>[];
      final List<PrismWallpaper> visibleWalls = <PrismWallpaper>[];
      String? nextCursor = refresh ? null : _lastDocId;
      bool hasMoreSourceRows = false;

      while (visibleWalls.length < _pageSize) {
        final List<_PrismRow> batch = await _firestoreClient
            .query<_PrismRow>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.walls,
                sourceTag: 'PrismWallpaperRepository.fetchFeed',
                filters: const <FirestoreFilter>[
                  FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
                ],
                orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
                startAfterDocId: nextCursor,
                limit: _pageSize,
                dedupeWindowMs: 1000,
                cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
              ),
              (data, docId) => (docId: docId, doc: PrismWallDocDto.fromJson(data)),
            )
            .timeout(_queryTimeout);
        if (generation != _feedGeneration) return Result.success(const <PrismWallpaper>[]);
        if (batch.isEmpty) {
          hasMoreSourceRows = false;
          break;
        }

        for (int i = 0; i < batch.length; i += 1) {
          final _PrismRow row = batch[i];
          traversedRows.add(row);
          nextCursor = row.docId;

          final PrismWallpaper wallpaper = row.doc.toDomain(docId: row.docId);
          if (!BlockedCreatorsFilter.hidesCreatorUid(wallpaper.core.authorUid, blocked)) {
            visibleWalls.add(wallpaper);
          }

          if (visibleWalls.length == _pageSize) {
            hasMoreSourceRows = i < batch.length - 1 || batch.length == _pageSize;
            break;
          }
        }

        if (visibleWalls.length == _pageSize) {
          break;
        }
        if (batch.length < _pageSize) {
          hasMoreSourceRows = false;
          break;
        }
        hasMoreSourceRows = true;
      }

      _lastDocId = nextCursor;
      _hasMore = hasMoreSourceRows;
      _remember(visibleWalls);
      try {
        await _writeCache(
          rows: traversedRows,
          hasMore: _hasMore,
          lastDocId: _lastDocId,
          append: !refresh,
          generation: generation,
        );
      } catch (error) {
        logger.w('[PrismWallpaperRepository] feed cache write failed: $error');
      }
      logger.i('[PrismWallpaperRepository] fetchFeed success', fields: <String, Object?>{'count': visibleWalls.length});
      return Result.success(visibleWalls);
    } catch (error, stackTrace) {
      final cached = refresh && generation == _feedGeneration ? await _readCached(generation: generation) : null;
      if (cached != null) {
        logger.w(
          '[PrismWallpaperRepository] remote fetch failed; returning cached snapshot',
          error: error,
          stackTrace: stackTrace,
        );
        return Result.success(cached);
      }
      logger.e('[PrismWallpaperRepository] fetchFeed failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch Prism feed: $error'));
    }
  }

  @override
  Future<Result<List<PrismWallpaper>>> fetchByCategory(
    String category, {
    String? startAfterDocId,
    int limit = _pageSize,
    String sourceTag = 'category_feed.prism_first',
  }) async {
    try {
      final List<_PrismRow> rows = await _firestoreClient
          .query<_PrismRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.walls,
              sourceTag: sourceTag,
              filters: <FirestoreFilter>[
                FirestoreFilter(field: 'category', op: FirestoreFilterOp.isEqualTo, value: category),
                const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
              ],
              orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
              startAfterDocId: startAfterDocId,
              limit: limit,
              dedupeWindowMs: 1000,
              cachePolicy: FirestoreCachePolicy.memoryFirst,
            ),
            (data, docId) => (docId: docId, doc: PrismWallDocDto.fromJson(data)),
          )
          .timeout(_queryTimeout);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
      return Result.success(
        rows
            .map((row) => row.doc.toDomain(docId: row.docId))
            .where((wall) => !BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked))
            .toList(growable: false),
      );
    } catch (error, stackTrace) {
      logger.e(
        '[PrismWallpaperRepository] fetchByCategory failed',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'category': category},
      );
      return Result.error(ServerFailure(wallpaperLoadFailureMessage, code: mapFirestoreError(error).code));
    }
  }

  @override
  Future<Result<List<PrismWallpaper>>> fetchStreakShopWallpapers() async {
    try {
      final List<_PrismRow> rows = await _firestoreClient.query<_PrismRow>(
        const FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'PrismWallpaperRepository.fetchStreakShop',
          filters: <FirestoreFilter>[
            FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'is_streak_exclusive', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          limit: 50,
          dedupeWindowMs: 1000,
        ),
        (data, docId) => (docId: docId, doc: PrismWallDocDto.fromJson(data)),
      );
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
      final List<PrismWallpaper> walls = rows
          .map((row) => row.doc.toDomain(docId: row.docId))
          .where((w) => !BlockedCreatorsFilter.hidesCreatorUid(w.core.authorUid, blocked))
          .toList(growable: false);
      walls.sort((a, b) {
        final aDays = a.requiredStreakDays ?? 999;
        final bDays = b.requiredStreakDays ?? 999;
        return aDays.compareTo(bDays);
      });
      logger.d(
        '[PrismWallpaperRepository] fetchStreakShopWallpapers',
        fields: <String, Object?>{'count': walls.length},
      );
      return Result.success(walls);
    } catch (error, stackTrace) {
      logger.e('[PrismWallpaperRepository] fetchStreakShopWallpapers failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch streak shop: $error'));
    }
  }

  @override
  Future<Result<PrismWallpaper?>> fetchCanonicalById(String id) async {
    if (id.trim().isEmpty) return Result.success(null);
    try {
      final List<_PrismRow> rows = await _firestoreClient
          .query<_PrismRow>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.walls,
              sourceTag: 'PrismWallpaperRepository.fetchCanonicalById',
              filters: <FirestoreFilter>[
                FirestoreFilter(field: 'id', op: FirestoreFilterOp.isEqualTo, value: id),
                const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
              ],
              limit: 2,
              cachePolicy: FirestoreCachePolicy.serverOnly,
            ),
            (data, docId) => (docId: docId, doc: PrismWallDocDto.fromJson(data)),
          )
          .timeout(_queryTimeout);
      if (rows.isEmpty) return Result.success(null);
      if (rows.length != 1) return Result.error(const ServerFailure('Ambiguous wallpaper identity'));
      final PrismWallpaper wall = rows.single.doc.toDomain(docId: rows.single.docId);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
      if (BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked)) return Result.success(null);
      return Result.success(wall);
    } catch (error, stackTrace) {
      logger.e('[PrismWallpaperRepository] canonical lookup failed', error: error, stackTrace: stackTrace);
      return Result.error(_lookupFailure(error));
    }
  }

  @override
  Future<Result<PrismWallpaper?>> fetchCanonicalByDocumentId(String documentId) async {
    if (documentId.trim().isEmpty) return Result.success(null);
    try {
      final List<Map<String, dynamic>> rows = await _firestoreClient
          .query<Map<String, dynamic>>(
            FirestoreQuerySpec(
              collection: FirebaseCollections.walls,
              sourceTag: 'PrismWallpaperRepository.fetchCanonicalByDocumentId',
              filters: <FirestoreFilter>[
                FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isEqualTo, value: documentId),
                const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
              ],
              limit: 1,
              cachePolicy: FirestoreCachePolicy.serverOnly,
            ),
            (data, _) => data,
          )
          .timeout(_queryTimeout);
      if (rows.isEmpty) return Result.success(null);
      final Map<String, dynamic> data = rows.single;
      if (data['review'] != true || data['originalProtected'] != true || (data['wallpaper_url'] ?? '') != '') {
        return Result.success(null);
      }
      final PrismWallpaper wall = PrismWallDocDto.fromJson(data).toDomain(docId: documentId);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
      if (BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked)) return Result.success(null);
      return Result.success(wall);
    } catch (error, stackTrace) {
      logger.e('[PrismWallpaperRepository] canonical document lookup failed', error: error, stackTrace: stackTrace);
      return Result.error(_lookupFailure(error));
    }
  }

  @override
  Future<Result<PrismWallpaper?>> fetchById(String id) async {
    try {
      final List<_PrismRow> results = await _firestoreClient.query<_PrismRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'PrismWallpaperRepository.fetchById',
          filters: <FirestoreFilter>[
            FirestoreFilter(field: 'id', op: FirestoreFilterOp.isEqualTo, value: id),
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          limit: 1,
        ),
        (data, docId) => (docId: docId, doc: PrismWallDocDto.fromJson(data)),
      );
      if (results.isEmpty) {
        // Wall of the Day notification links carry the Firestore doc id, not the `id` field.
        final Result<PrismWallpaper?> byDocId = await fetchByDocumentId(id);
        if (byDocId.isFailure) return byDocId;
        return byDocId.data?.review == true ? byDocId : Result.success(null);
      }
      final PrismWallpaper wall = results.first.doc.toDomain(docId: results.first.docId);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
      if (BlockedCreatorsFilter.hidesCreatorUid(wall.core.authorUid, blocked)) {
        return Result.success(null);
      }
      _remember(<PrismWallpaper>[wall]);
      return Result.success(wall);
    } catch (error, stackTrace) {
      logger.e('[PrismWallpaperRepository] fetchById failed', error: error, stackTrace: stackTrace);
      return Result.error(_lookupFailure(error));
    }
  }

  @override
  Future<Result<PrismWallpaper?>> fetchByDocumentId(String documentId) async {
    if (documentId.isEmpty) {
      return Result.success(null);
    }
    try {
      final Map<String, dynamic>? data = await _firestoreClient.getById<Map<String, dynamic>>(
        FirebaseCollections.walls,
        documentId,
        (d, _) => d,
        sourceTag: 'PrismWallpaperRepository.fetchByDocumentId',
      );
      if (data == null) {
        return Result.success(null);
      }
      final PrismWallpaper wallpaper = PrismWallDocDto.fromJson(data).toDomain(docId: documentId);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
      if (BlockedCreatorsFilter.hidesCreatorUid(wallpaper.core.authorUid, blocked)) {
        return Result.success(null);
      }
      if (wallpaper.review == true) _remember(<PrismWallpaper>[wallpaper]);
      return Result.success(wallpaper);
    } catch (error, stackTrace) {
      logger.e('[PrismWallpaperRepository] fetchByDocumentId failed', error: error, stackTrace: stackTrace);
      return Result.error(_lookupFailure(error));
    }
  }

  Failure _lookupFailure(Object error) {
    final String? code = mapFirestoreError(error).code;
    if (error is TimeoutException ||
        const <String>{'unavailable', 'deadline-exceeded', 'network-request-failed'}.contains(code)) {
      return NetworkFailure(wallpaperLoadFailureMessage, code: code);
    }
    return ServerFailure(wallpaperLoadFailureMessage, code: code);
  }

  Future<void> _writeCache({
    required List<_PrismRow> rows,
    required bool hasMore,
    required String? lastDocId,
    required bool append,
    required int generation,
  }) async {
    final FeedSnapshot? previous = append ? await _feedCacheLocal.read(source: 'prism', scope: 'main') : null;
    if (generation != _feedGeneration) return;
    return _feedCacheLocal.write(
      source: 'prism',
      scope: 'main',
      ttlHours: _feedTtlHours,
      payload: OfflineSnapshotCodec.encodePrismFeed(
        previous: previous,
        rows: rows.map((row) => <String, Object?>{'docId': row.docId, 'doc': toJsonSafe(row.doc.toJson())}).toList(),
        append: append,
        hasMore: hasMore,
        lastDocId: lastDocId,
      ),
    );
  }

  void _remember(Iterable<PrismWallpaper> walls) {
    unawaited(_persistRemembered(walls));
  }

  Future<void> _persistRemembered(Iterable<PrismWallpaper> walls) async {
    try {
      await OfflineWallpaperCatalog.instance.remember(walls.map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall)));
    } catch (error) {
      logger.w('[PrismWallpaperRepository] local catalog write failed: $error');
    }
  }

  Future<List<PrismWallpaper>?> _readCached({required int generation}) async {
    final snapshot = await _feedCacheLocal.read(source: 'prism', scope: 'main');
    if (generation != _feedGeneration) return null;
    final payload = toJsonMap(snapshot?.payload);
    final mappedRows = ((payload['rows'] as List?) ?? const <Object?>[])
        .map(toJsonMap)
        .map((entry) {
          final doc = toJsonMap(entry['doc']);
          final docId = entry['docId']?.toString() ?? '';
          if (docId.isEmpty || doc.isEmpty) {
            return null;
          }
          return (docId: docId, doc: PrismWallDocDto.fromJson(doc));
        })
        .nonNulls
        .toList(growable: false);

    if (mappedRows.isEmpty) {
      return null;
    }

    final Set<String> blocked = await _userBlockRepository.getBlockedCreatorUids(waitForInitialLoad: true);
    if (generation != _feedGeneration) return null;
    _hasMore = payload['hasMore'] == true;
    final String? cachedLastDocId = payload['lastDocId']?.toString();
    if (cachedLastDocId != null && cachedLastDocId.isNotEmpty) {
      _lastDocId = cachedLastDocId;
    }

    return mappedRows
        .map((row) => row.doc.toDomain(docId: row.docId))
        .where((w) => !BlockedCreatorsFilter.hidesCreatorUid(w.core.authorUid, blocked))
        .toList(growable: false);
  }
}

typedef _PrismRow = ({String docId, PrismWallDocDto doc});
