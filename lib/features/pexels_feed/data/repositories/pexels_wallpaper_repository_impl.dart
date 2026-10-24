import 'dart:async';
import 'dart:io';

import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:Prism/data/feed_cache/pagination_session.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/data/dtos/pexels_dtos.dart';
import 'package:Prism/features/pexels_feed/data/mappers/pexels_dto_mapper.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

@LazySingleton(as: PexelsWallpaperRepository)
class PexelsWallpaperRepositoryImpl implements PexelsWallpaperRepository, PaginationSession {
  PexelsWallpaperRepositoryImpl(this._local);

  final FeedCacheLocalDataSource _local;
  final Map<String, PagedFeedCache> _feedCaches = <String, PagedFeedCache>{};

  @visibleForTesting
  int get activePaginationSessions => _feedCaches.length;

  @override
  void releasePaginationKey(String paginationKey) => _feedCaches.remove(paginationKey);

  PagedFeedCache _cacheFor(String key, {bool refresh = false}) {
    if (!refresh && _feedCaches.containsKey(key)) return _feedCaches[key]!;
    return _feedCaches[key] = PagedFeedCache(_local, source: 'pexels', durable: !isEphemeralPaginationKey(key));
  }

  static const String _host = 'api.pexels.com';
  static const String _searchPath = '/v1/search';
  static const String _curatedPath = '/v1/curated';
  static const String _photosPath = '/v1/photos';
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _perPage = 80;

  /// The home feed ranks 24 items per page from a few queries, so it asks for fewer photos per query.
  static const String _personalizedKeyPrefix = 'personalized:';
  static const int _personalizedPerPage = 30;

  @override
  bool hasMoreForCategory(String categoryName, {String? paginationKey}) =>
      _feedCaches[paginationKey ?? categoryName]?.hasMore(paginationKey ?? categoryName) ?? true;

  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
    String? color,
  }) {
    return _fetchPage(
      categoryName,
      refresh: refresh,
      startPage: startPage,
      paginationKey: paginationKey,
      portraitOnly: portraitOnly,
      buildUri: (page) => categoryName == 'Curated'
          ? Uri.https(_host, _curatedPath, <String, String>{'per_page': '24', 'page': page.toString()})
          : _searchUri(
              query: categoryName,
              page: page,
              portraitOnly: portraitOnly,
              color: color,
              perPage: (paginationKey ?? '').startsWith(_personalizedKeyPrefix) ? _personalizedPerPage : _perPage,
            ),
    );
  }

  Uri _searchUri({
    required String query,
    required int page,
    required bool portraitOnly,
    String? color,
    int perPage = _perPage,
  }) {
    return Uri.https(_host, _searchPath, <String, String>{
      'query': query,
      if (portraitOnly) 'orientation': 'portrait',
      'color': ?color,
      'per_page': perPage.toString(),
      'page': page.toString(),
    });
  }

  Future<Result<List<PexelsWallpaper>>> _fetchPage(
    String categoryName, {
    required bool refresh,
    required Uri Function(int page) buildUri,
    int startPage = 1,
    String? paginationKey,
    bool portraitOnly = true,
  }) async {
    final String pageKey = paginationKey ?? categoryName;
    final PagedFeedCache cache = _cacheFor(pageKey, refresh: refresh);

    final String scope = _scope(categoryName, paginationKey, portraitOnly: portraitOnly);
    final int page = refresh ? startPage : cache.pageFor(pageKey);
    final Uri uri = buildUri(page);

    try {
      final http.Response response = await PerformanceProbe.measure(
        'http',
        'pexels.search',
        () => http
            .get(uri, headers: <String, String>{'Authorization': Env.normalize(Env.pexelsApiKey)})
            .timeout(_requestTimeout),
      );
      if (response.statusCode != 200) {
        return await _cachedOrFailure(
          refresh: refresh,
          pageKey: pageKey,
          cache: cache,
          scope: scope,
          failure: ServerFailure(
            'Pexels feed request failed (${response.statusCode}): ${response.reasonPhrase ?? 'unknown'}',
          ),
        );
      }

      final Map<String, dynamic> decoded = decodeJsonMap(response.body);
      final PexelsSearchResponseDto payload = PexelsSearchResponseDto.fromJson(decoded);
      final int currentPage = payload.page == 0 ? page : payload.page;
      final int totalPages = payload.perPage > 0 ? (payload.totalResults / payload.perPage).ceil() : currentPage;
      final bool hasMore = totalPages == 0 ? payload.photos.isNotEmpty : currentPage < totalPages;

      final List<PexelsWallpaper> walls = payload.photos.map((item) => item.toDomain()).toList(growable: false);
      if (!identical(_feedCaches[pageKey], cache)) return Result.success(walls);
      _remember(walls);
      try {
        await cache.write(
          pageKey,
          scope: scope,
          payload: payload.toJson(),
          nextPage: currentPage + 1,
          hasMore: hasMore,
          append: !refresh,
          isCurrent: () => identical(_feedCaches[pageKey], cache),
        );
      } catch (error) {
        logger.w('[PexelsWallpaperRepository] feed cache write failed: $error');
        if (identical(_feedCaches[pageKey], cache)) {
          cache.advance(pageKey, nextPage: currentPage + 1, hasMore: hasMore);
        }
      }

      logger.i(
        '[PexelsWallpaperRepository] fetchFeed success',
        fields: <String, Object?>{'category': categoryName, 'count': walls.length},
      );
      return Result.success(walls);
    } catch (error, stackTrace) {
      final cached = refresh ? await _readCached(pageKey: pageKey, scope: scope, cache: cache) : null;
      if (cached != null) {
        logger.w(
          '[PexelsWallpaperRepository] remote fetch failed; returning cached snapshot',
          error: error,
          stackTrace: stackTrace,
          fields: <String, Object?>{'category': categoryName},
        );
        return Result.success(cached);
      }
      logger.e('[PexelsWallpaperRepository] fetchFeed failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch Pexels feed: $error'));
    }
  }

  @override
  Future<Result<PexelsWallpaper?>> fetchById(String id) async {
    final Uri uri = Uri.https(_host, '$_photosPath/$id');
    try {
      final http.Response response = await PerformanceProbe.measure(
        'http',
        'pexels.by_id',
        () => http
            .get(uri, headers: <String, String>{'Authorization': Env.normalize(Env.pexelsApiKey)})
            .timeout(_requestTimeout),
      );
      if (response.statusCode != 200) {
        return Result.error(
          ServerFailure(
            'Pexels wallpaper request failed (${response.statusCode}): ${response.reasonPhrase ?? 'unknown'}',
          ),
        );
      }

      final Map<String, dynamic> decoded = decodeJsonMap(response.body);
      final PexelsWallpaper wallpaper = PexelsPhotoDto.fromJson(decoded).toDomain();
      _remember(<PexelsWallpaper>[wallpaper]);
      return Result.success(wallpaper);
    } catch (error, stackTrace) {
      logger.e('[PexelsWallpaperRepository] fetchById failed', error: error, stackTrace: stackTrace);
      return Result.error(_lookupFailure(error));
    }
  }

  Failure _lookupFailure(Object error) => switch (error) {
    SocketException() => const NetworkFailure(wallpaperLoadFailureMessage, code: 'socket_error'),
    HandshakeException() => const NetworkFailure(wallpaperLoadFailureMessage, code: 'tls_error'),
    TimeoutException() => const NetworkFailure(wallpaperLoadFailureMessage, code: 'timeout'),
    http.ClientException() => const NetworkFailure(wallpaperLoadFailureMessage, code: 'http_client_error'),
    _ => ServerFailure('Failed to fetch Pexels wallpaper by id: $error', code: error.runtimeType.toString()),
  };

  Future<Result<List<PexelsWallpaper>>> _cachedOrFailure({
    required PagedFeedCache cache,
    required bool refresh,
    required String pageKey,
    required String scope,
    required Failure failure,
  }) async {
    final cached = refresh ? await _readCached(pageKey: pageKey, scope: scope, cache: cache) : null;
    if (cached != null) {
      logger.w(
        '[PexelsWallpaperRepository] remote status failed; returning cached snapshot',
        fields: <String, Object?>{'scope': scope},
      );
      return Result.success(cached);
    }
    return Result.error(failure);
  }

  Future<List<PexelsWallpaper>?> _readCached({
    required String pageKey,
    required String scope,
    required PagedFeedCache cache,
  }) => cache.read(
    pageKey,
    scope: scope,
    decode: (payload) =>
        PexelsSearchResponseDto.fromJson(payload).photos.map((item) => item.toDomain()).toList(growable: false),
  );

  String _scope(String categoryName, String? paginationKey, {required bool portraitOnly}) {
    final String slug = feedCacheSlug(
      paginationKey == null || paginationKey == categoryName ? categoryName : '$categoryName.$paginationKey',
    );
    return portraitOnly ? '$slug.portrait' : slug;
  }

  void _remember(Iterable<PexelsWallpaper> walls) {
    unawaited(_persistRemembered(walls));
  }

  Future<void> _persistRemembered(Iterable<PexelsWallpaper> walls) async {
    try {
      await OfflineWallpaperCatalog.instance.remember(
        walls.map((wall) => PexelsFeedItem(id: wall.id, wallpaper: wall)),
      );
    } catch (error) {
      logger.w('[PexelsWallpaperRepository] local catalog write failed: $error');
    }
  }
}
