import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/data/feed_cache/paged_feed_cache.dart';
import 'package:Prism/features/wallhaven_feed/data/dtos/wallhaven_dtos.dart';
import 'package:Prism/features/wallhaven_feed/data/mappers/wallhaven_dto_mapper.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

@LazySingleton(as: WallhavenWallpaperRepository)
class WallhavenWallpaperRepositoryImpl implements WallhavenWallpaperRepository {
  WallhavenWallpaperRepositoryImpl(FeedCacheLocalDataSource feedCacheLocal)
    : _cache = PagedFeedCache(feedCacheLocal, source: 'wallhaven');

  final PagedFeedCache _cache;

  static const String _host = 'wallhaven.cc';
  static const String _searchPath = '/api/v1/search';
  static const String _toplistKey = 'toplist';
  static const String _toplistScope = 'toplist.3d';

  @override
  bool hasMoreForCategory(String categoryName, {String? paginationKey}) =>
      _cache.hasMore(paginationKey ?? categoryName);

  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
    int startPage = 1,
    String? paginationKey,
  }) async {
    final String pageKey = paginationKey ?? categoryName;
    if (refresh) {
      _cache.reset(pageKey);
    }

    final int page = refresh ? startPage : _cache.pageFor(pageKey);
    final Uri uri = Uri.https(_host, _searchPath, <String, String>{
      'q': categoryName,
      'page': page.toString(),
      'categories': categories.toString(),
      'purity': purity.toString(),
    });

    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200) {
        return await _cachedOrFailure(
          categoryName: categoryName,
          paginationKey: paginationKey,
          categories: categories,
          purity: purity,
          failure: ServerFailure(
            'WallHaven feed request failed (${response.statusCode}): ${response.reasonPhrase ?? 'unknown'}',
          ),
        );
      }

      final Map<String, dynamic> decoded = decodeJsonMap(response.body);
      final WallhavenSearchResponseDto payload = WallhavenSearchResponseDto.fromJson(decoded);
      final int currentPage = payload.meta?.currentPage ?? page;
      final int lastPage = payload.meta?.lastPage ?? currentPage;
      final bool hasMore = currentPage < lastPage;

      final List<WallhavenWallpaper> walls = payload.data.map((item) => item.toDomain()).toList(growable: false);

      await _cache.write(
        pageKey,
        scope: _scope(categoryName: categoryName, categories: categories, purity: purity, paginationKey: paginationKey),
        payload: payload.toJson(),
        nextPage: currentPage + 1,
        hasMore: hasMore,
      );

      logger.i(
        '[WallhavenWallpaperRepository] fetchFeed success',
        fields: <String, Object?>{'category': categoryName, 'count': walls.length},
      );
      return Result.success(walls);
    } catch (error, stackTrace) {
      final cached = await _readCached(
        categoryName: categoryName,
        categories: categories,
        purity: purity,
        paginationKey: paginationKey,
      );
      if (cached != null) {
        logger.w(
          '[WallhavenWallpaperRepository] remote fetch failed; returning cached snapshot',
          error: error,
          stackTrace: stackTrace,
          fields: <String, Object?>{'category': categoryName},
        );
        return Result.success(cached);
      }
      logger.e('[WallhavenWallpaperRepository] fetchFeed failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch WallHaven feed: $error'));
    }
  }

  @override
  Future<Result<List<WallhavenWallpaper>>> fetchToplist({int page = 1}) async {
    final Uri uri = Uri.https(_host, _searchPath, <String, String>{
      'sorting': 'toplist',
      'topRange': '3d',
      'purity': '100',
      'categories': '100',
      'page': page.toString(),
    });

    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200) {
        return await _cachedToplistOrFailure(
          failure: ServerFailure(
            'WallHaven toplist request failed (${response.statusCode}): ${response.reasonPhrase ?? 'unknown'}',
          ),
        );
      }

      final Map<String, dynamic> decoded = decodeJsonMap(response.body);
      final WallhavenSearchResponseDto payload = WallhavenSearchResponseDto.fromJson(decoded);
      final List<WallhavenWallpaper> walls = payload.data.map((item) => item.toDomain()).toList(growable: false);

      await _cache.write(
        _toplistKey,
        scope: _toplistScope,
        payload: payload.toJson(),
        nextPage: page + 1,
        hasMore: walls.isNotEmpty,
      );

      logger.i('[WallhavenWallpaperRepository] fetchToplist success', fields: <String, Object?>{'count': walls.length});
      return Result.success(walls);
    } catch (error, stackTrace) {
      final cached = await _readCachedToplist();
      if (cached != null) {
        logger.w(
          '[WallhavenWallpaperRepository] toplist fetch failed; returning cached snapshot',
          error: error,
          stackTrace: stackTrace,
        );
        return Result.success(cached);
      }
      logger.e('[WallhavenWallpaperRepository] fetchToplist failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch WallHaven toplist: $error'));
    }
  }

  Future<Result<List<WallhavenWallpaper>>> _cachedToplistOrFailure({required Failure failure}) async {
    final cached = await _readCachedToplist();
    if (cached != null) {
      return Result.success(cached);
    }
    return Result.error(failure);
  }

  Future<List<WallhavenWallpaper>?> _readCachedToplist() =>
      _cache.read(_toplistKey, scope: _toplistScope, decode: _decodeWalls);

  @override
  Future<Result<WallhavenWallpaper?>> fetchById(String id) async {
    final Uri uri = Uri.https(_host, '/api/v1/w/${id.toLowerCase()}');
    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200) {
        return Result.error(
          ServerFailure(
            'WallHaven wallpaper request failed (${response.statusCode}): ${response.reasonPhrase ?? 'unknown'}',
          ),
        );
      }

      final Map<String, dynamic> decoded = decodeJsonMap(response.body);
      final WallhavenSingleResponseDto payload = WallhavenSingleResponseDto.fromJson(decoded);
      return Result.success(payload.data?.toDomain());
    } catch (error, stackTrace) {
      logger.e('[WallhavenWallpaperRepository] fetchById failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch WallHaven wallpaper by id: $error'));
    }
  }

  Future<Result<List<WallhavenWallpaper>>> _cachedOrFailure({
    required String categoryName,
    required int categories,
    required int purity,
    String? paginationKey,
    required Failure failure,
  }) async {
    final cached = await _readCached(
      categoryName: categoryName,
      categories: categories,
      purity: purity,
      paginationKey: paginationKey,
    );
    if (cached != null) {
      logger.w(
        '[WallhavenWallpaperRepository] remote status failed; returning cached snapshot',
        fields: <String, Object?>{'category': categoryName},
      );
      return Result.success(cached);
    }
    return Result.error(failure);
  }

  Future<List<WallhavenWallpaper>?> _readCached({
    required String categoryName,
    required int categories,
    required int purity,
    String? paginationKey,
  }) => _cache.read(
    paginationKey ?? categoryName,
    scope: _scope(categoryName: categoryName, categories: categories, purity: purity, paginationKey: paginationKey),
    decode: _decodeWalls,
  );

  List<WallhavenWallpaper> _decodeWalls(Map<String, dynamic> payload) =>
      WallhavenSearchResponseDto.fromJson(payload).data.map((item) => item.toDomain()).toList(growable: false);

  String _scope({required String categoryName, required int categories, required int purity, String? paginationKey}) {
    final String cacheKey = paginationKey == null || paginationKey == categoryName
        ? categoryName
        : '$categoryName.$paginationKey';
    return '${feedCacheSlug(cacheKey)}.$categories.$purity';
  }
}
