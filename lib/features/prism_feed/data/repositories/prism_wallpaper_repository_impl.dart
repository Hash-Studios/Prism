import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: PrismWallpaperRepository)
class PrismWallpaperRepositoryImpl implements PrismWallpaperRepository {
  PrismWallpaperRepositoryImpl(this._firestoreClient, this._feedCacheLocal);

  final FirestoreClient _firestoreClient;
  final FeedCacheLocalDataSource _feedCacheLocal;

  String? _lastDocId;
  bool _hasMore = true;
  static const int _pageSize = 24;
  static const int _feedTtlHours = 6;

  @override
  bool get hasMore => _hasMore;

  @override
  Future<Result<List<PrismWallpaper>>> fetchFeed({required bool refresh}) async {
    if (refresh) {
      _lastDocId = null;
      _hasMore = true;
    }

    logger.d('[PrismWallpaperRepository] fetchFeed', fields: <String, Object?>{'refresh': refresh});

    try {
      final List<_PrismRow> rows = await _firestoreClient.query<_PrismRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'PrismWallpaperRepository.fetchFeed',
          filters: const <FirestoreFilter>[
            FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          startAfterDocId: refresh ? null : _lastDocId,
          limit: _pageSize,
          dedupeWindowMs: 1000,
          cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
        ),
        (data, docId) => _PrismRow(docId: docId, doc: PrismWallDocDto.fromJson(data)),
      );
      final List<PrismWallpaper> walls = rows.map((row) => row.doc.toDomain(docId: row.docId)).toList(growable: false);
      if (rows.isNotEmpty) {
        _lastDocId = rows.last.docId;
      }

      _hasMore = walls.length == _pageSize;
      await _writeCache(rows: rows, hasMore: _hasMore, lastDocId: _lastDocId);
      logger.i('[PrismWallpaperRepository] fetchFeed success', fields: <String, Object?>{'count': walls.length});
      return Result.success(walls);
    } catch (error, stackTrace) {
      final cached = _readCached();
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
  Future<Result<PrismWallpaper?>> fetchById(String id) async {
    try {
      final List<_PrismRow> results = await _firestoreClient.query<_PrismRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'PrismWallpaperRepository.fetchById',
          filters: <FirestoreFilter>[FirestoreFilter(field: 'id', op: FirestoreFilterOp.isEqualTo, value: id)],
          limit: 1,
        ),
        (data, docId) => _PrismRow(docId: docId, doc: PrismWallDocDto.fromJson(data)),
      );
      if (results.isEmpty) {
        return Result.success(null);
      }
      return Result.success(results.first.doc.toDomain(docId: results.first.docId));
    } catch (error, stackTrace) {
      logger.e('[PrismWallpaperRepository] fetchById failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch Prism wallpaper by id: $error'));
    }
  }

  Future<void> _writeCache({required List<_PrismRow> rows, required bool hasMore, required String? lastDocId}) {
    return _feedCacheLocal.write(
      source: 'prism',
      scope: 'main',
      ttlHours: _feedTtlHours,
      payload: <String, Object?>{
        'rows': rows
            .map((row) => <String, Object?>{'docId': row.docId, 'doc': row.doc.toJson()})
            .toList(growable: false),
        'hasMore': hasMore,
        'lastDocId': lastDocId,
      },
    );
  }

  List<PrismWallpaper>? _readCached() {
    final snapshot = _feedCacheLocal.read(source: 'prism', scope: 'main');
    if (snapshot == null || snapshot.payload is! Map) {
      return null;
    }

    final payload = _asMap(snapshot.payload);
    final rows = payload['rows'];
    if (rows is! List) {
      return null;
    }

    final mappedRows = rows
        .whereType<Map>()
        .map(_asMap)
        .map((entry) {
          final doc = _asMap(entry['doc']);
          final docId = entry['docId']?.toString() ?? '';
          if (docId.isEmpty || doc.isEmpty) {
            return null;
          }
          return _PrismRow(docId: docId, doc: PrismWallDocDto.fromJson(doc));
        })
        .whereType<_PrismRow>()
        .toList(growable: false);

    if (mappedRows.isEmpty) {
      return null;
    }

    _hasMore = payload['hasMore'] == true;
    final String? cachedLastDocId = payload['lastDocId']?.toString();
    if (cachedLastDocId != null && cachedLastDocId.isNotEmpty) {
      _lastDocId = cachedLastDocId;
    }

    return mappedRows.map((row) => row.doc.toDomain(docId: row.docId)).toList(growable: false);
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map<String, dynamic>((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

class _PrismRow {
  const _PrismRow({required this.docId, required this.doc});

  final String docId;
  final PrismWallDocDto doc;
}
