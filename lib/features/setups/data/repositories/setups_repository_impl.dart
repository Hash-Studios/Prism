import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/setups/data/mappers/setup_doc_mapper.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';
import 'package:Prism/features/setups/domain/repositories/setups_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SetupsRepository)
class SetupsRepositoryImpl implements SetupsRepository {
  SetupsRepositoryImpl(this._firestoreClient, this._feedCacheLocal, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final UserBlockRepository _userBlockRepository;
  String? _cursorDocId;
  static const int _pageSize = 10;
  static const int _setupsReadDedupeMs = 30000;
  static const int _setupsCacheTtlHours = 3;

  @override
  Future<Result<SetupsPage>> fetchSetups({required bool refresh}) async {
    try {
      final rows = await _firestoreClient.query<_SetupRow>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.setups,
          sourceTag: 'setups.fetch_setups',
          filters: const <FirestoreFilter>[
            FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
          limit: _pageSize,
          startAfterDocId: refresh ? null : _cursorDocId,
          cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
          dedupeWindowMs: refresh ? 0 : _setupsReadDedupeMs,
        ),
        (data, docId) => (docId: docId, doc: SetupDocDto.fromJson(data)),
      );
      if (rows.isNotEmpty) {
        _cursorDocId = rows.last.docId;
      }

      final page = SetupsPage(
        items: await _visibleItems(rows),
        hasMore: rows.length == _pageSize,
        nextCursor: _cursorDocId,
      );
      await _writeCache(rows: rows, page: page);
      return Result.success(page);
    } catch (error) {
      logger.w('fetchSetups failed, falling back to cache', error: error);
      final cached = await _readCached();
      if (cached != null) {
        return Result.success(cached);
      }
      return Result.error(ServerFailure('Failed to load setups: $error'));
    }
  }

  Future<void> _writeCache({required List<_SetupRow> rows, required SetupsPage page}) {
    return _feedCacheLocal.write(
      source: 'setups',
      scope: 'main',
      ttlHours: _setupsCacheTtlHours,
      payload: <String, Object?>{
        'rows': rows
            .map((row) => <String, Object?>{'docId': row.docId, 'doc': row.doc.toJson()})
            .toList(growable: false),
        'hasMore': page.hasMore,
        'nextCursor': page.nextCursor,
      },
    );
  }

  Future<SetupsPage?> _readCached() async {
    final snapshot = await _feedCacheLocal.read(source: 'setups', scope: 'main');
    if (snapshot == null || snapshot.payload is! Map) {
      return null;
    }

    final payload = toJsonMap(snapshot.payload);
    final rows = payload['rows'];
    if (rows is! List) {
      return null;
    }

    final mappedRows = rows
        .whereType<Map>()
        .map(toJsonMap)
        .map((entry) {
          final String docId = entry['docId']?.toString() ?? '';
          final Map<String, dynamic> docMap = toJsonMap(entry['doc']);
          if (docId.isEmpty || docMap.isEmpty) {
            return null;
          }
          return (docId: docId, doc: SetupDocDto.fromJson(docMap));
        })
        .whereType<_SetupRow>()
        .toList(growable: false);

    if (mappedRows.isEmpty) {
      return null;
    }

    _cursorDocId = payload['nextCursor']?.toString();
    return SetupsPage(
      items: await _visibleItems(mappedRows),
      hasMore: payload['hasMore'] == true,
      nextCursor: _cursorDocId,
    );
  }

  Future<List<SetupEntity>> _visibleItems(List<_SetupRow> rows) async {
    final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
    return rows
        .map((row) => row.doc.toSetupEntity(row.docId))
        .where((s) => !BlockedCreatorsFilter.hidesCreatorEmail(s.email, blocked))
        .toList(growable: false);
  }

  @override
  Future<Result<SetupEntity?>> fetchSetupByName(String name) async {
    try {
      final rows = await _firestoreClient.query<SetupEntity>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.setups,
          sourceTag: 'setups.lookup.byName',
          // Rules only let non-owners read reviewed setups, so the query must say so.
          filters: <FirestoreFilter>[
            FirestoreFilter(field: 'name', op: FirestoreFilterOp.isEqualTo, value: name),
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
          ],
          limit: 1,
        ),
        (data, docId) => SetupDocDto.fromJson(data).toSetupEntity(docId),
      );
      return Result.success(rows.isEmpty ? null : rows.first);
    } catch (error) {
      logger.w('fetchSetupByName failed', error: error);
      return Result.error(ServerFailure('Failed to load setup: $error'));
    }
  }
}

typedef _SetupRow = ({String docId, SetupDocDto doc});
