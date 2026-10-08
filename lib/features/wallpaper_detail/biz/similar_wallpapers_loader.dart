import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/logger/logger.dart';

/// Finds walls like the one on screen. Prism walls share a category. Wallhaven walls share their first tag.
/// Any failure gives an empty list, because the strip is optional.
class SimilarWallpapersLoader {
  SimilarWallpapersLoader({
    required FirestoreClient Function() firestore,
    required UserBlockRepository Function() blocks,
    required WallpaperSearchService Function() search,
  }) : _firestore = firestore,
       _blocks = blocks,
       _search = search;

  factory SimilarWallpapersLoader.fromGetIt() => SimilarWallpapersLoader(
    firestore: () => getIt<FirestoreClient>(),
    blocks: () => getIt<UserBlockRepository>(),
    search: () => getIt<WallpaperSearchService>(),
  );

  static const int limit = 12;
  static const String sourceTag = 'wallpaper_detail.similar';

  final FirestoreClient Function() _firestore;
  final UserBlockRepository Function() _blocks;
  final WallpaperSearchService Function() _search;

  Future<List<FeedItemEntity>> load(FeedItemEntity current) async {
    try {
      final List<FeedItemEntity> found = await switch (current) {
        PrismFeedItem() => _loadPrism(current),
        WallhavenFeedItem() => _loadByTag(current),
        PexelsFeedItem() => Future<List<FeedItemEntity>>.value(const <FeedItemEntity>[]),
      };
      return found.where((item) => item.id != current.id).take(limit).toList(growable: false);
    } catch (error, stackTrace) {
      logger.w('Similar wallpapers failed', error: error, stackTrace: stackTrace);
      return const <FeedItemEntity>[];
    }
  }

  Future<List<FeedItemEntity>> _loadPrism(PrismFeedItem current) async {
    final String category = current.wallpaper.core.category?.trim() ?? '';
    if (category.isEmpty) return const <FeedItemEntity>[];
    final List<FeedItemEntity> rows = await _firestore().query<FeedItemEntity>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: sourceTag,
        filters: <FirestoreFilter>[
          FirestoreFilter(field: 'category', op: FirestoreFilterOp.isEqualTo, value: category),
          const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        ],
        orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
        limit: limit + 1,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
      ),
      (data, docId) {
        final wall = PrismWallDocDto.fromJson(data).toDomain(docId: docId);
        return PrismFeedItem(id: wall.id, wallpaper: wall);
      },
    );
    final Set<String> blocked = await _blocks().getBlockedCreatorEmails(waitForInitialLoad: true);
    return BlockedCreatorsFilter.filterFeedItems(rows, blocked);
  }

  Future<List<FeedItemEntity>> _loadByTag(WallhavenFeedItem current) async {
    final List<String> tags = wallpaperTags(current);
    if (tags.isEmpty) return const <FeedItemEntity>[];
    final page = await _search().search(tags.first);
    return page.results;
  }
}
