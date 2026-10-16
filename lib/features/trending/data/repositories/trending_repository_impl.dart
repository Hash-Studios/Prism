import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/domain/repositories/trending_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: TrendingRepository)
class TrendingRepositoryImpl implements TrendingRepository {
  TrendingRepositoryImpl(this._firestoreClient, this._feedCacheLocal, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final UserBlockRepository _userBlockRepository;

  static const int _whereInLimit = 30;
  static const int _cacheTtlHours = 3;
  static const String _cacheSource = 'trending';
  static const String trendingLoadFailureMessage =
      "Couldn't load trending wallpapers. Check your connection and try again.";

  static String _collection(TrendingRange range) => switch (range) {
    TrendingRange.week => 'trending',
    TrendingRange.allTime => 'popular',
  };

  @override
  Future<Result<List<PrismWallpaper>>> fetch(TrendingRange range) async {
    try {
      final Map<String, dynamic>? doc = await _firestoreClient.getById<Map<String, dynamic>>(
        _collection(range),
        'current',
        (data, _) => data,
        sourceTag: 'trending.${range.name}.ids',
      );
      final List<String> ids = _wallIds(doc?['wallIds']);
      final List<PrismWallpaper> walls = await _loadWalls(ids, range);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
      final List<PrismWallpaper> visible = _visible(walls, blocked);
      await _writeCache(range, visible);
      return Result.success(visible);
    } catch (error, stackTrace) {
      final List<PrismWallpaper>? cached = await _readCached(range);
      if (cached != null) {
        logger.w('[TrendingRepository] fetch failed; returning the saved list', error: error, stackTrace: stackTrace);
        return Result.success(cached);
      }
      logger.e('[TrendingRepository] fetch failed', error: error, stackTrace: stackTrace);
      return Result.error(const ServerFailure(trendingLoadFailureMessage));
    }
  }

  /// Loads the walls by id in batches of 30 and puts them back in the order of [ids].
  Future<List<PrismWallpaper>> _loadWalls(List<String> ids, TrendingRange range) async {
    final List<List<PrismWallpaper>> batches = await Future.wait(
      ids.slices(_whereInLimit).map((batch) {
        return _firestoreClient.query<PrismWallpaper>(
          FirestoreQuerySpec(
            collection: FirebaseCollections.walls,
            sourceTag: 'trending.${range.name}.walls',
            filters: <FirestoreFilter>[
              const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
              FirestoreFilter(field: 'id', op: FirestoreFilterOp.whereIn, value: batch),
            ],
            limit: _whereInLimit,
            cachePolicy: FirestoreCachePolicy.memoryFirst,
          ),
          (data, docId) => PrismWallDocDto.fromJson(data).toDomain(docId: docId),
        );
      }),
    );
    final Map<String, PrismWallpaper> byId = <String, PrismWallpaper>{
      for (final PrismWallpaper wall in batches.expand((batch) => batch)) wall.id.toUpperCase(): wall,
    };
    return <PrismWallpaper>[for (final String id in ids) ?byId[id]];
  }

  List<PrismWallpaper> _visible(List<PrismWallpaper> walls, Set<String> blocked) => walls
      .where(
        (wall) => wall.fullUrl.isNotEmpty && !BlockedCreatorsFilter.hidesCreatorEmail(wall.core.authorEmail, blocked),
      )
      .toList(growable: false);

  Future<void> _writeCache(TrendingRange range, List<PrismWallpaper> walls) async {
    try {
      await _feedCacheLocal.write(
        source: _cacheSource,
        scope: range.name,
        ttlHours: _cacheTtlHours,
        payload: <String, Object?>{
          'items': walls
              .map((wall) => encodeFeedItem(PrismFeedItem(id: wall.id, wallpaper: wall)))
              .toList(growable: false),
        },
      );
    } catch (error) {
      logger.w('[TrendingRepository] cache write failed: $error');
    }
  }

  Future<List<PrismWallpaper>?> _readCached(TrendingRange range) async {
    try {
      final FeedSnapshot? snapshot = await _feedCacheLocal.read(source: _cacheSource, scope: range.name);
      final Object? rawItems = toJsonMap(snapshot?.payload)['items'];
      if (rawItems is! List) return null;
      final List<PrismWallpaper> walls = rawItems
          .whereType<Map>()
          .map((entry) => decodeFeedItem(toJsonMap(entry)))
          .whereType<PrismFeedItem>()
          .map((item) => item.wallpaper)
          .toList(growable: false);
      final Set<String> blocked = await _userBlockRepository.getBlockedCreatorEmails(waitForInitialLoad: true);
      return _visible(walls, blocked);
    } catch (error) {
      logger.w('[TrendingRepository] cache read failed: $error');
      return null;
    }
  }
}

List<String> _wallIds(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((id) => id?.toString().trim().toUpperCase() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
