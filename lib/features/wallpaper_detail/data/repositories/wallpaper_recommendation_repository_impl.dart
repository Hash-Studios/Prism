import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/ranking_rules.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/data/feed_cache/pagination_session.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/feed_impression_store.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wallpaper_recommendation_repository.dart';
import 'package:Prism/logger/logger.dart';

/// A visit owns its external page key. Detail never borrows the search screen's mutable cursor.
final class WallpaperRecommendationRepositoryImpl implements WallpaperRecommendationRepository {
  WallpaperRecommendationRepositoryImpl({
    required this.firestore,
    required this.wallhaven,
    required this.pexels,
    required this.settings,
    required this.blocks,
    required this.localSearch,
    this.rules = _legacyRules,
    this.tasteProfile = _noTaste,
    this.hiddenKeys = _noHidden,
  });

  static RankingRules _legacyRules() => RankingRules.legacy;
  static TasteProfile _noTaste() => TasteProfile.empty;
  static Set<String> _noHidden() => const <String>{};

  factory WallpaperRecommendationRepositoryImpl.fromGetIt() => WallpaperRecommendationRepositoryImpl(
    firestore: () => getIt<FirestoreClient>(),
    wallhaven: () => getIt<WallhavenWallpaperRepository>(),
    pexels: () => getIt<PexelsWallpaperRepository>(),
    settings: () => getIt<SettingsLocalDataSource>(),
    blocks: () => getIt<UserBlockRepository>(),
    localSearch: (query) => OfflineWallpaperCatalog.instance.search(query),
    rules: () => RankingRules.current,
    tasteProfile: () => getIt<PersonalizedFeedRepository>().currentTasteProfile(),
    hiddenKeys: () => <String>{
      for (final MapEntry<String, int> entry
          in getIt<FeedImpressionStore>().recentShows(DateTime.now().toUtc()).entries)
        if (entry.value >= FeedImpressionStore.hiddenShows) entry.key,
    },
  );

  static const pageSize = 24;
  final FirestoreClient Function() firestore;
  final WallhavenWallpaperRepository Function() wallhaven;
  final PexelsWallpaperRepository Function() pexels;
  final SettingsLocalDataSource Function() settings;
  final UserBlockRepository Function() blocks;
  final Future<List<FeedItemEntity>> Function(String) localSearch;
  final RankingRules Function() rules;
  final TasteProfile Function() tasteProfile;

  /// Walls the user hid with "Show less like this".
  final Set<String> Function() hiddenKeys;
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
    final blocked = await blocks().loadBlockedCreators();
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
        PrismFeedItem(:final wallpaper) => await _prism(
          query,
          wallpaper.firestoreDocumentId,
          cursor as PrismRecommendationCursor?,
          kind,
        ),
        WallhavenFeedItem() => await _external(sessionKey, visit, cursor as ExternalRecommendationCursor?),
        PexelsFeedItem() => await _pexels(sessionKey, visit, cursor as ExternalRecommendationCursor?),
      };
      visit.ensureActive();
      return RecommendationPage(
        items: _personal(current, visit, visible(page.items)),
        kind: page.kind,
        nextCursor: page.nextCursor,
      );
    } catch (_) {
      // A later-page failure is retryable, not an excuse to replace an already loaded feed with local results.
      if (!visit.active || cursor != null) rethrow;
      final rows = await localSearch(query.isEmpty ? current.source.name : query);
      visit.ensureActive();
      final purity = settings().get<int>('WHpurity', defaultValue: 100);
      final local = visible(rows).where((item) => _allowsCachedWallhaven(item, visit.categories, purity)).toList();
      if (local.isEmpty) rethrow;
      return RecommendationPage(items: _personal(current, visit, local), kind: RecommendationKind.offline);
    }
  }

  /// Starts after [anchor], the open wall, so each wall gets its own neighbours instead of the same newest page.
  /// When the older walls run out, it goes back to the newest ones and stops at [anchor].
  Future<RecommendationPage> _prism(
    String category,
    String? anchor,
    PrismRecommendationCursor? cursor,
    RecommendationKind kind,
  ) async {
    var start = (anchor?.isEmpty ?? true) ? null : anchor;
    final cursorDocumentId = cursor == null ? start : cursor.documentId;
    List<Object?>? startAfterFieldValues;
    if (cursorDocumentId != null) {
      try {
        final data = await firestore().getById<Map<String, dynamic>>(
          FirebaseCollections.walls,
          cursorDocumentId,
          (data, _) => data,
          sourceTag: 'wallpaper_detail.recommendations.cursor',
        );
        // Field presence matters: null and legacy values are still valid Firestore ordering values.
        if (data != null && data.containsKey('createdAt')) {
          startAfterFieldValues = [data['createdAt'], cursorDocumentId];
        } else if (cursor == null) {
          start = null;
        }
      } catch (error) {
        // An active unreviewed Drop can be readable only through its public Drop document.
        if (mapFirestoreError(error).code != 'permission-denied') rethrow;
        if (cursor == null) start = null;
      }
    }
    final wrapped = cursor?.wrapped ?? false;
    final rows = await firestore().query<_PrismRow>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.walls,
        sourceTag: 'wallpaper_detail.recommendations',
        filters: [
          if (category.isNotEmpty) FirestoreFilter(field: 'category', op: FirestoreFilterOp.isEqualTo, value: category),
          const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
        ],
        orderBy: const [
          FirestoreOrderBy(field: 'createdAt', descending: true),
          FirestoreOrderBy(field: firestoreDocumentIdField, descending: true),
        ],
        startAfterFieldValues: startAfterFieldValues,
        limit: pageSize,
        cachePolicy: FirestoreCachePolicy.memoryFirst,
      ),
      (data, docId) {
        final wall = PrismWallDocDto.fromJson(data).toDomain(docId: docId);
        return _PrismRow(docId, PrismFeedItem(id: wall.id, wallpaper: wall));
      },
    );
    final visited = cursor?.visitedDocumentIds ?? const <String>{};
    final stop = rows.indexWhere((row) => (wrapped && row.documentId == start) || visited.contains(row.documentId));
    final kept = stop < 0 ? rows : rows.sublist(0, stop);
    // Advance from the raw last document, even when every item is blocked, anime, or a duplicate.
    final PrismRecommendationCursor? next = switch ((stop >= 0, rows.length < pageSize)) {
      (true, _) => null,
      (false, false) => PrismRecommendationCursor(
        rows.last.documentId,
        wrapped: wrapped,
        visitedDocumentIds: Set.unmodifiable({...visited, ...rows.map((row) => row.documentId)}),
      ),
      (false, true) =>
        wrapped || start == null
            ? null
            : PrismRecommendationCursor(
                null,
                wrapped: true,
                visitedDocumentIds: Set.unmodifiable({...visited, ...rows.map((row) => row.documentId)}),
              ),
    };
    return RecommendationPage(items: kept.map((row) => row.item).toList(growable: false), kind: kind, nextCursor: next);
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

  /// With [RankingRules.personalNextWalls], each page ranks by what it shares with [current], then the user's taste.
  /// A light/dark group shows once in the whole visit.
  List<FeedItemEntity> _personal(FeedItemEntity current, _RecommendationVisit visit, List<FeedItemEntity> items) {
    if (!rules().personalNextWalls) return items;
    final List<FeedItemEntity> ranked;
    try {
      ranked = rankNextWalls(
        current: current,
        items: items,
        profile: tasteProfile(),
        hiddenKeys: hiddenKeys(),
        usedGroups: visit.variantGroups,
      );
    } catch (error) {
      // A taste lookup failure is not a network failure. Keep the query order instead of the offline fallback.
      logger.w('More like this kept the query order: $error');
      return items;
    }
    for (final FeedItemEntity item in ranked) {
      if (item case PrismFeedItem(:final wallpaper) when wallpaper.variantGroupId != null) {
        visit.variantGroups.add(wallpaper.variantGroupId!);
      }
    }
    return ranked;
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
  final Set<String> variantGroups = {};
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
