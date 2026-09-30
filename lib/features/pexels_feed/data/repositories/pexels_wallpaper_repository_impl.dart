import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/pexels_feed/data/dtos/pexels_dtos.dart';
import 'package:Prism/features/pexels_feed/data/mappers/pexels_dto_mapper.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

@LazySingleton(as: PexelsWallpaperRepository)
class PexelsWallpaperRepositoryImpl implements PexelsWallpaperRepository {
  PexelsWallpaperRepositoryImpl(FeedCacheLocalDataSource feedCacheLocal)
    : _cache = PagedFeedCache(feedCacheLocal, source: 'pexels');

  final PagedFeedCache _cache;

  static const String _host = 'api.pexels.com';
  static const String _searchPath = '/v1/search';
  static const String _curatedPath = '/v1/curated';
  static const String _photosPath = '/v1/photos';

  @override
  bool hasMoreForCategory(String categoryName) => _cache.hasMore(categoryName);

  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({required String categoryName, required bool refresh}) {
    return _fetchPage(
      categoryName,
      refresh: refresh,
      buildUri: (page) => categoryName == 'Curated'
          ? Uri.https(_host, _curatedPath, <String, String>{'per_page': '24', 'page': page.toString()})
          : _searchUri(query: categoryName, page: page),
    );
  }

  @override
  Future<Result<List<PexelsWallpaper>>> fetchColorFeed({required String hex, required bool refresh}) {
    final String color = hex.trim().replaceFirst('#', '').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{6}$').hasMatch(color)) {
      return Future<Result<List<PexelsWallpaper>>>.value(Result.error(ValidationFailure('Invalid color: $hex')));
    }
    return _fetchPage(
      'color: $color',
      refresh: refresh,
      buildUri: (page) => _searchUri(query: 'wallpaper', page: page, color: '#$color'),
    );
  }

  Uri _searchUri({required String query, required int page, String? color}) {
    return Uri.https(_host, _searchPath, <String, String>{
      'query': query,
      'color': ?color,
      'per_page': '80',
      'page': page.toString(),
    });
  }

  Future<Result<List<PexelsWallpaper>>> _fetchPage(
    String categoryName, {
    required bool refresh,
    required Uri Function(int page) buildUri,
  }) async {
    if (refresh) {
      _cache.reset(categoryName);
    }

    final int page = _cache.pageFor(categoryName);
    final Uri uri = buildUri(page);

    try {
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{'Authorization': Env.normalize(Env.pexelsApiKey)},
      );
      if (response.statusCode != 200) {
        return await _cachedOrFailure(
          categoryName: categoryName,
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

      await _cache.write(
        categoryName,
        scope: feedCacheSlug(categoryName),
        payload: payload.toJson(),
        nextPage: currentPage + 1,
        hasMore: hasMore,
      );

      logger.i(
        '[PexelsWallpaperRepository] fetchFeed success',
        fields: <String, Object?>{'category': categoryName, 'count': walls.length},
      );
      return Result.success(walls);
    } catch (error, stackTrace) {
      final cached = await _readCached(categoryName: categoryName);
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
      final http.Response response = await http.get(
        uri,
        headers: <String, String>{'Authorization': Env.normalize(Env.pexelsApiKey)},
      );
      if (response.statusCode != 200) {
        return Result.error(
          ServerFailure(
            'Pexels wallpaper request failed (${response.statusCode}): ${response.reasonPhrase ?? 'unknown'}',
          ),
        );
      }

      final Map<String, dynamic> decoded = decodeJsonMap(response.body);
      return Result.success(PexelsPhotoDto.fromJson(decoded).toDomain());
    } catch (error, stackTrace) {
      logger.e('[PexelsWallpaperRepository] fetchById failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch Pexels wallpaper by id: $error'));
    }
  }

  Future<Result<List<PexelsWallpaper>>> _cachedOrFailure({
    required String categoryName,
    required Failure failure,
  }) async {
    final cached = await _readCached(categoryName: categoryName);
    if (cached != null) {
      logger.w(
        '[PexelsWallpaperRepository] remote status failed; returning cached snapshot',
        fields: <String, Object?>{'category': categoryName},
      );
      return Result.success(cached);
    }
    return Result.error(failure);
  }

  Future<List<PexelsWallpaper>?> _readCached({required String categoryName}) => _cache.read(
    categoryName,
    scope: feedCacheSlug(categoryName),
    decode: (payload) =>
        PexelsSearchResponseDto.fromJson(payload).photos.map((item) => item.toDomain()).toList(growable: false),
  );
}
