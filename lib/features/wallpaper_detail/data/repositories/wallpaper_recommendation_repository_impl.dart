import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/data/feed_cache/pagination_session.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wallpaper_recommendation_repository.dart';

/// A visit owns its external page key. Detail never borrows the search screen's mutable cursor.
final class WallpaperRecommendationRepositoryImpl implements WallpaperRecommendationRepository {
  WallpaperRecommendationRepositoryImpl({
    required this.firestore,
    required this.wallhaven,
    required this.pexels,
    required this.settings,
    required this.blocks,
    required this.localSearch,
  });

  factory WallpaperRecommendationRepositoryImpl.fromGetIt() => WallpaperRecommendationRepositoryImpl(
    firestore: () => getIt<FirestoreClient>(),
    wallhaven: () => getIt<WallhavenWallpaperRepository>(),
    pexels: () => getIt<PexelsWallpaperRepository>(),
    settings: () => getIt<SettingsLocalDataSource>(),
    blocks: () => getIt<UserBlockRepository>(),
    localSearch: (query) => OfflineWallpaperCatalog.instance.search(query),
  );

  static const pageSize = 24;
  final FirestoreClient Function() firestore;
  final WallhavenWallpaperRepository Function() wallhaven;
  final PexelsWallpaperRepository Function() pexels;
  final SettingsLocalDataSource Function() settings;
  final UserBlockRepository Function() blocks;
  final Future<List<FeedItemEntity>> Function(String) localSearch;
  final Map<String, _RecommendationVisit> _visits = {};

  @override
  void release(String sessionKey) {
    final visit = _visits.remove(sessionKey);
    if (visit == null) return;
    visit.active = false;
    for (final repo in visit.providers) {
      repo.releasePaginationKey('$ephemeralPaginationPrefix$sessionKey:wallhaven');
      repo.releasePaginationKey('$ephemeralPaginationPrefix$sessionKey:pexels');
    }
  }

  @override
  Future<RecommendationPage> load({
    required FeedItemEntity current,
    required String sessionKey,
    RecommendationCursor? cursor,
  }) async {
    final category = current.wallpaperCore.category?.trim() ?? '';
    final tags = wallpaperTags(current);
    // Only the wallpaper's own category or tags make a related query; without them the visit is discovery.
    final related = switch (current) {
      PrismFeedItem() => category.isNotEmpty,
      WallhavenFeedItem() => tags.isNotEmpty,
      PexelsFeedItem() => false,
    };
    final visit = _visits.putIfAbsent(
      sessionKey,
      () => _RecommendationVisit(
        related ? (current is PrismFeedItem ? category : tags.first) : '',
        related ? RecommendationKind.related : RecommendationKind.discovery,
        settings().get<int>('WHcategories', defaultValue: 100),
        settings().get<int>('WHpurity', defaultValue: 100),
      ),
    );
    final query = visit.query;
    final kind = visit.kind;
    final blocked = await blocks().getBlockedCreatorUids(waitForInitialLoad: true);
    List<FeedItemEntity> visible(List<FeedItemEntity> rows) {
      final showAnime = AnimeContentFilter.showsAnime(settings());
      final showAi = AiContentFilter.showsAi(settings());
      return AiContentFilter.filterFeedItems(
        AnimeContentFilter.filterFeedItems(BlockedCreatorsFilter.filterFeedItems(rows, blocked), showAnime: showAnime),
        showAi: showAi,
      );
    }

    try {
      visit.ensureActive();
      final page = switch (current) {
        PrismFeedItem() => await _prism(query, cursor as PrismRecommendationCursor?, kind),
        WallhavenFeedItem() => await _external(sessionKey, visit, cursor as ExternalRecommendationCursor?),
        PexelsFeedItem() => await _pexels(sessionKey, visit, cursor as ExternalRecommendationCursor?),
      };
      visit.ensureActive();
      return RecommendationPage(items: visible(page.items), kind: page.kind, nextCursor: page.nextCursor);
    } catch (_) {
      // A later-page failure is retryable, not an excuse to replace an already loaded feed with local results.
      if (!visit.active || cursor != null) rethrow;
      final rows = await localSearch(query.isEmpty ? current.source.name : query);
      visit.ensureActive();
      final purity = settings().get<int>('WHpurity', defaultValue: 100);
      final local = visible(rows).where((item) => _allowsCachedWallhaven(item, visit.categories, purity)).toList();
      if (local.isEmpty) rethrow;
      return RecommendationPage(items: local, kind: RecommendationKind.offline);
    }
  }

  Future<RecommendationPage> _prism(String category, PrismRecommendationCursor? cursor, RecommendationKind kind) async {
    final rows = await firestore().query<_PrismRow>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'wallpaper_detail.recommendations',
        filters: [
          if (category.isNotEmpty) FirestoreFilter(field: 'category', op: FirestoreFilterOp.isEqualTo, value: category),
          const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        ],
        orderBy: const [FirestoreOrderBy(field: 'createdAt', descending: true)],
        startAfterDocId: cursor?.documentId,
        limit: pageSize,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
      ),
      (data, docId) {
        final wall = PrismWallDocDto.fromJson(data).toDomain(docId: docId);
        return _PrismRow(docId, PrismFeedItem(id: wall.id, wallpaper: wall));
      },
    );
    // Advance from the raw last document, even when every item is blocked, anime, or a duplicate.
    return RecommendationPage(
      items: rows.map((row) => row.item).toList(growable: false),
      kind: kind,
      nextCursor: rows.length < pageSize ? null : PrismRecommendationCursor(rows.last.documentId),
    );
  }

  Future<RecommendationPage> _wallhaven(
    String sessionKey,
    _RecommendationVisit visit,
    ExternalRecommendationCursor? cursor,
  ) async {
    final repo = wallhaven();
    if (repo is PaginationSession) visit.providers.add(repo as PaginationSession);
    final key = '$ephemeralPaginationPrefix$sessionKey:wallhaven';
    final result = await repo.fetchFeed(
      categoryName: visit.query,
      refresh: cursor == null,
      startPage: cursor?.page ?? 1,
      paginationKey: key,
      categories: visit.categories,
      purity: visit.purity,
    );
    visit.ensureActive();
    if (result.isFailure) throw StateError(result.failure!.message);
    return RecommendationPage(
      items: result.data!.map((wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false),
      kind: visit.kind,
      nextCursor: repo.hasMoreForCategory(visit.query, paginationKey: key)
          ? ExternalRecommendationCursor((cursor?.page ?? 1) + 1)
          : null,
    );
  }

  Future<RecommendationPage> _external(
    String sessionKey,
    _RecommendationVisit visit,
    ExternalRecommendationCursor? cursor,
  ) async {
    if (cursor?.provider == RecommendationProvider.pexels) return _pexels(sessionKey, visit, cursor);
    try {
      return await _wallhaven(sessionKey, visit, cursor);
    } catch (_) {
      if (!visit.active || cursor != null) rethrow;
      return _pexels(sessionKey, visit, null);
    }
  }

  Future<RecommendationPage> _pexels(
    String sessionKey,
    _RecommendationVisit visit,
    ExternalRecommendationCursor? cursor,
  ) async {
    final repo = pexels();
    if (repo is PaginationSession) visit.providers.add(repo as PaginationSession);
    final key = '$ephemeralPaginationPrefix$sessionKey:pexels';
    final result = await repo.fetchFeed(
      categoryName: 'Curated',
      refresh: cursor == null,
      startPage: cursor?.page ?? 1,
      paginationKey: key,
    );
    visit.ensureActive();
    if (result.isFailure) throw StateError(result.failure!.message);
    return RecommendationPage(
      items: result.data!.map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false),
      kind: RecommendationKind.discovery,
      nextCursor: repo.hasMoreForCategory('Curated', paginationKey: key)
          ? ExternalRecommendationCursor((cursor?.page ?? 1) + 1, provider: RecommendationProvider.pexels)
          : null,
    );
  }

  bool _allowsCachedWallhaven(FeedItemEntity item, int categories, int purity) {
    if (item is! WallhavenFeedItem) return true;
    // The offline catalog does not retain Wallhaven purity, so restricted requests cannot verify these rows.
    if (purity != 111) return false;
    return switch (item.wallpaperCore.category?.trim().toLowerCase()) {
      'general' => categories ~/ 100 % 10 == 1,
      'anime' => categories ~/ 10 % 10 == 1,
      'people' => categories % 10 == 1,
      _ => categories ~/ 10 % 10 == 1 || !wallpaperTags(item).any((tag) => tag.toLowerCase() == 'anime'),
    };
  }
}

final class _RecommendationVisit {
  _RecommendationVisit(this.query, this.kind, this.categories, this.purity);
  final String query;
  final RecommendationKind kind;
  final int categories;
  final int purity;
  final Set<PaginationSession> providers = {};
  bool active = true;

  void ensureActive() {
    if (!active) throw StateError('Recommendation visit released');
  }
}

final class _PrismRow {
  const _PrismRow(this.documentId, this.item);
  final String documentId;
  final FeedItemEntity item;
}
