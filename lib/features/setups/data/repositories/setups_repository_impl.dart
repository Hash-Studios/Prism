import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';
import 'package:Prism/features/setups/domain/repositories/setups_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: SetupsRepository)
class SetupsRepositoryImpl implements SetupsRepository {
  SetupsRepositoryImpl(this._firestoreClient, this._feedCacheLocal, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final UserBlockRepository _userBlockRepository;
  String? _cursorDocId;
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
          limit: 10,
          startAfterDocId: refresh ? null : _cursorDocId,
          cachePolicy: refresh ? FirestoreCachePolicy.networkOnly : FirestoreCachePolicy.memoryFirst,
          dedupeWindowMs: refresh ? 0 : _setupsReadDedupeMs,
        ),
        (data, docId) => _SetupRow(docId: docId, doc: SetupDocDto.fromJson(data)),
      );
      if (rows.isNotEmpty) {
        _cursorDocId = rows.last.docId;
      }

      final Set<String> blocked = _userBlockRepository.cachedBlockedCreatorEmails;
      final items = rows
          .map((row) => _mapSetup(row.doc, row.docId))
          .where((s) => !BlockedCreatorsFilter.hidesCreatorEmail(s.email, blocked))
          .toList(growable: false);
      final page = SetupsPage(items: items, hasMore: rows.length == 10, nextCursor: _cursorDocId);
      await _writeCache(rows: rows, page: page);
      return Result.success(page);
    } catch (error) {
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

    final payload = _asMap(snapshot.payload);
    final rows = payload['rows'];
    if (rows is! List) {
      return null;
    }

    final mappedRows = rows
        .whereType<Map>()
        .map(_asMap)
        .map((entry) {
          final String docId = entry['docId']?.toString() ?? '';
          final Map<String, dynamic> docMap = _asMap(entry['doc']);
          if (docId.isEmpty || docMap.isEmpty) {
            return null;
          }
          return _SetupRow(docId: docId, doc: SetupDocDto.fromJson(docMap));
        })
        .whereType<_SetupRow>()
        .toList(growable: false);

    if (mappedRows.isEmpty) {
      return null;
    }

    final Set<String> blocked = _userBlockRepository.cachedBlockedCreatorEmails;
    final items = mappedRows
        .map((row) => _mapSetup(row.doc, row.docId))
        .where((s) => !BlockedCreatorsFilter.hidesCreatorEmail(s.email, blocked))
        .toList(growable: false);
    _cursorDocId = payload['nextCursor']?.toString();
    return SetupsPage(items: items, hasMore: payload['hasMore'] == true, nextCursor: _cursorDocId);
  }

  SetupEntity _mapSetup(SetupDocDto dto, String docId) {
    return SetupEntity(
      id: dto.id.isNotEmpty ? dto.id : docId,
      by: dto.by,
      icon: dto.icon,
      iconUrl: dto.iconUrl,
      createdAt: dto.createdAt,
      desc: dto.desc,
      email: dto.email,
      image: dto.image,
      name: dto.name,
      userPhoto: dto.userPhoto,
      wallId: dto.wallId,
      source: WallpaperSourceX.fromWire(dto.wallpaperProvider),
      wallpaperThumb: dto.wallpaperThumb,
      wallpaperUrl: dto.wallpaperUrl,
      widget: dto.widget,
      widget2: dto.widget2,
      widgetUrl: dto.widgetUrl,
      widgetUrl2: dto.widgetUrl2,
      link: dto.link,
      review: dto.review,
      resolution: dto.resolution,
      size: dto.size,
      firestoreDocumentId: docId,
    );
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

class _SetupRow {
  const _SetupRow({required this.docId, required this.doc});

  final String docId;
  final SetupDocDto doc;
}
