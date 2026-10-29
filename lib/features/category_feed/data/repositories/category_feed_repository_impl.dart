import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/anime_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/category_catalog.dart';
import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/category_feed_page.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/domain/repositories/category_feed_repository.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: CategoryFeedRepository)
class CategoryFeedRepositoryImpl implements CategoryFeedRepository {
  CategoryFeedRepositoryImpl(
    this._settingsLocal,
    this._feedCacheLocal,
    this._prismRepository,
    this._wallhavenRepository,
    this._pexelsRepository,
  );

  final SettingsLocalDataSource _settingsLocal;
  final FeedCacheLocalDataSource _feedCacheLocal;
  final PrismWallpaperRepository _prismRepository;
  final WallhavenWallpaperRepository _wallhavenRepository;
  final PexelsWallpaperRepository _pexelsRepository;
  final Map<String, int> _generations = <String, int>{};

  static const int _feedTtlHours = 6;
  static const Duration _prismFirstTimeout = Duration(seconds: 10);

  @override
  Future<Result<List<CategoryEntity>>> getCategories() async {
    final categories = CategoryCatalog.current
        .map(
          (def) => CategoryEntity(
            name: def.name,
            source: def.source,
            searchType: def.searchType,
            image: def.imageUrl,
            image2: def.secondaryImageUrl,
            hasPrismWalls: def.hasPrismWalls,
          ),
        )
        .toList(growable: false);

    return Result.success(categories);
  }

  @override
  Future<Result<CategoryFeedPage>> fetchCategoryFeed({required CategoryEntity category, required bool refresh}) async {
    final mode = refresh ? 'r' : 'm';
    final String scope = _scopeFor(category);
    final UserBlockRepository? blockRepository = getIt.isRegistered<UserBlockRepository>()
        ? getIt<UserBlockRepository>()
        : null;
    final BlockedCreators? blocksAtStart = blockRepository?.blockedCreators;
    final int generation = refresh ? (_generations[scope] ?? 0) + 1 : (_generations[scope] ?? 0);
    _generations[scope] = generation;
    bool isCurrent() => _generations[scope] == generation;

    try {
      final Future<List<FeedItemEntity>> prismFirst = refresh
          ? _fetchPrismFirst(category).timeout(_prismFirstTimeout, onTimeout: () => const <FeedItemEntity>[])
          : Future.value(const <FeedItemEntity>[]);
      final fetched = await _fetchFromSource(category, refresh: refresh);
      if (!isCurrent()) return Result.error(const UnknownFailure('Category request was invalidated'));
      final CategoryFeedPage? providerPage = fetched.data;
      final page = providerPage == null
          ? null
          : CategoryFeedPage(
              items: AiContentFilter.filterFeedItems(
                AnimeContentFilter.filterFeedItems(
                  _prependPrism(await prismFirst, providerPage.items),
                  showAnime: AnimeContentFilter.showsAnime(_settingsLocal),
                ),
                showAi: AiContentFilter.showsAi(_settingsLocal),
              ),
              hasMore: providerPage.hasMore,
            );
      if (page == null) {
        final failure = fetched.failure ?? const UnknownFailure('Failed to fetch feed');
        if (!refresh) {
          return Result.error(failure);
        }
        return await _cachedOrFailure(category: category, mode: mode, failure: failure);
      }
      if (!isCurrent()) return Result.error(const UnknownFailure('Category request was invalidated'));

      if (_canWriteCache(blockRepository, blocksAtStart)) {
        try {
          await _writeCache(category, page, append: !refresh, isCurrent: isCurrent);
        } catch (error) {
          logger.w('[CategoryFeedRepository] feed cache write failed: $error');
        }
      }
      if (isCurrent()) _remember(page.items);

      logger.i(
        '[CategoryFeedRepository] fetchCategoryFeed success',
        fields: <String, Object?>{
          'category': category.name,
          'provider': category.source.legacyProviderString,
          'mode': mode,
          'itemCount': page.items.length,
          'hasMore': page.hasMore,
        },
      );

      return Result.success(page);
    } catch (error, stackTrace) {
      final cached = refresh ? await _readCached(category) : null;
      if (cached != null) {
        logger.w(
          '[CategoryFeedRepository] remote fetch failed; returning cached snapshot',
          error: error,
          stackTrace: stackTrace,
          fields: <String, Object?>{'category': category.name, 'provider': category.source.legacyProviderString},
        );
        return Result.success(cached);
      }

      logger.e(
        '[CategoryFeedRepository] fetchCategoryFeed failed',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{
          'category': category.name,
          'provider': category.source.legacyProviderString,
          'mode': mode,
        },
      );
      return Result.error(ServerFailure('Failed to fetch category feed: $error'));
    }
  }

  bool _canWriteCache(UserBlockRepository? repository, BlockedCreators? blocksAtStart) =>
      repository == null || (blocksAtStart is KnownBlockedCreators && repository.blockedCreators == blocksAtStart);

  /// Prism creator walls that match a category with classifier data. Never fails the feed.
  Future<List<FeedItemEntity>> _fetchPrismFirst(CategoryEntity category) async {
    if (!category.hasPrismWalls || category.source == WallpaperSource.prism) {
      return const <FeedItemEntity>[];
    }
    final result = await _prismRepository.fetchByCategory(category.name);
    final walls = result.data;
    if (walls == null) {
      logger.w(
        '[CategoryFeedRepository] Prism-first walls failed; showing the provider feed only',
        fields: <String, Object?>{'category': category.name, 'failure': result.failure?.message},
      );
      return const <FeedItemEntity>[];
    }
    return walls.map((wall) => PrismFeedItem(id: wall.id, wallpaper: wall)).toList(growable: false);
  }

  List<FeedItemEntity> _prependPrism(List<FeedItemEntity> prism, List<FeedItemEntity> provider) {
    if (prism.isEmpty) return provider;
    final Map<String, FeedItemEntity> unique = <String, FeedItemEntity>{};
    for (final FeedItemEntity item in <FeedItemEntity>[...prism, ...provider]) {
      unique.putIfAbsent(_canonicalKey(item), () => item);
    }
    return unique.values.toList(growable: false);
  }

  String _canonicalKey(FeedItemEntity item) {
    final String url = item.fullUrl.trim().toLowerCase();
    return url.isNotEmpty ? url : '${item.source.wireValue}:${item.id.trim().toLowerCase()}';
  }

  Future<Result<CategoryFeedPage>> _fetchFromSource(CategoryEntity category, {required bool refresh}) async {
    switch (category.source) {
      case WallpaperSource.prism:
        final result = await _prismRepository.fetchFeed(refresh: refresh);
        return _toPage(
          result,
          label: 'Prism',
          toItem: (wall) => PrismFeedItem(id: wall.id, wallpaper: wall),
          hasMore: _prismRepository.hasMore,
        );
      case WallpaperSource.wallhaven:
        final result = await _wallhavenRepository.fetchFeed(
          categoryName: category.name,
          refresh: refresh,
          categories: _settingsLocal.get<int>('WHcategories', defaultValue: 100),
          purity: _settingsLocal.get<int>('WHpurity', defaultValue: 100),
        );
        return _toPage(
          result,
          label: 'Wallhaven',
          toItem: (wall) => WallhavenFeedItem(id: wall.id, wallpaper: wall),
          hasMore: _wallhavenRepository.hasMoreForCategory(category.name),
        );
      case WallpaperSource.pexels:
        final result = await _pexelsRepository.fetchFeed(categoryName: category.name, refresh: refresh);
        return _toPage(
          result,
          label: 'Pexels',
          toItem: (wall) => PexelsFeedItem(id: wall.id, wallpaper: wall),
          hasMore: _pexelsRepository.hasMoreForCategory(category.name),
        );
      case WallpaperSource.downloaded:
      case WallpaperSource.unknown:
        return Result.error(const ValidationFailure('Unsupported category source'));
    }
  }

  Result<CategoryFeedPage> _toPage<W>(
    Result<List<W>> result, {
    required String label,
    required FeedItemEntity Function(W wall) toItem,
    required bool hasMore,
  }) {
    final walls = result.data;
    if (walls == null) {
      return Result.error(result.failure ?? UnknownFailure('Failed to fetch $label feed'));
    }
    return Result.success(CategoryFeedPage(items: walls.map(toItem).toList(growable: false), hasMore: hasMore));
  }

  Future<void> _writeCache(
    CategoryEntity category,
    CategoryFeedPage page, {
    required bool append,
    required bool Function() isCurrent,
  }) async {
    List<FeedItemEntity> items = page.items;
    if (append) {
      final CategoryFeedPage? previous = await _readCached(category);
      if (previous != null) {
        final Map<String, FeedItemEntity> merged = <String, FeedItemEntity>{
          for (final FeedItemEntity item in previous.items) _canonicalKey(item): item,
          for (final FeedItemEntity item in page.items) _canonicalKey(item): item,
        };
        items = merged.values.toList(growable: false);
      }
    }
    if (!isCurrent()) return;
    while (items.length > 240 ||
        utf8
                .encode(
                  jsonEncode(<String, Object?>{
                    'cachedAtUtc': DateTime.now().toUtc().toIso8601String(),
                    'ttlHours': _feedTtlHours,
                    'payload': <String, Object?>{
                      'items': items.map(encodeFeedItem).toList(growable: false),
                      'hasMore': page.hasMore,
                    },
                  }),
                )
                .length >
            FeedCacheLocalDataSource.maxSnapshotBytes) {
      if (items.isEmpty) break;
      items = items.skip(1).toList(growable: false);
    }
    return _feedCacheLocal.write(
      source: 'category',
      scope: _scopeFor(category),
      ttlHours: _feedTtlHours,
      payload: <String, Object?>{'items': items.map(encodeFeedItem).toList(growable: false), 'hasMore': page.hasMore},
    );
  }

  void _remember(Iterable<FeedItemEntity> items) {
    unawaited(_persistRemembered(items));
  }

  Future<void> _persistRemembered(Iterable<FeedItemEntity> items) async {
    try {
      await OfflineWallpaperCatalog.instance.remember(items);
    } catch (error) {
      logger.w('[CategoryFeedRepository] local catalog write failed: $error');
    }
  }

  Future<Result<CategoryFeedPage>> _cachedOrFailure({
    required CategoryEntity category,
    required String mode,
    required Failure failure,
  }) async {
    final cached = await _readCached(category);
    if (cached != null) {
      logger.w(
        '[CategoryFeedRepository] provider failed; returning cached snapshot',
        fields: <String, Object?>{
          'category': category.name,
          'provider': category.source.legacyProviderString,
          'mode': mode,
        },
      );
      return Result.success(cached);
    }
    return Result.error(failure);
  }

  Future<CategoryFeedPage?> _readCached(CategoryEntity category) async {
    final snapshot = await _feedCacheLocal.read(source: 'category', scope: _scopeFor(category));
    final payload = toJsonMap(snapshot?.payload);
    final bool showAnime = AnimeContentFilter.showsAnime(_settingsLocal);
    final bool showAi = AiContentFilter.showsAi(_settingsLocal);
    // A cache written while anime or AI was on may hold those Prism walls.
    final items = ((payload['items'] as List?) ?? const <Object?>[])
        .map((entry) => decodeFeedItem(toJsonMap(entry)))
        .nonNulls
        .where((item) => !AnimeContentFilter.hidesFeedItem(item, showAnime: showAnime))
        .where((item) => !AiContentFilter.hidesFeedItem(item, showAi: showAi))
        .toList(growable: false);

    if (items.isEmpty) {
      return null;
    }

    if (!getIt.isRegistered<UserBlockRepository>()) {
      return CategoryFeedPage(items: items, hasMore: payload['hasMore'] == true);
    }
    final blocked = await getIt<UserBlockRepository>().loadBlockedCreators();
    final visibleItems = items.where((item) => !BlockedCreatorsFilter.hidesFeedItem(item, blocked)).toList();
    return visibleItems.isEmpty ? null : CategoryFeedPage(items: visibleItems, hasMore: payload['hasMore'] == true);
  }

  String _scopeFor(CategoryEntity category) {
    final String base = '${category.source.wireValue}.${category.searchType.name}.${feedCacheSlug(category.name)}';
    return switch (category.source) {
      WallpaperSource.wallhaven =>
        '$base.${_settingsLocal.get<int>('WHcategories', defaultValue: 100)}'
            '.${_settingsLocal.get<int>('WHpurity', defaultValue: 100)}.portrait',
      WallpaperSource.pexels => '$base.portrait',
      _ => base,
    };
  }
}
