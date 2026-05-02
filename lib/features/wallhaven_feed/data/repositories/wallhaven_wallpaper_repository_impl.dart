import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/wallhaven_feed/data/dtos/wallhaven_dtos.dart';
import 'package:Prism/features/wallhaven_feed/data/mappers/wallhaven_dto_mapper.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

@LazySingleton(as: WallhavenWallpaperRepository)
class WallhavenWallpaperRepositoryImpl implements WallhavenWallpaperRepository {
  WallhavenWallpaperRepositoryImpl(this._feedCacheLocal);

  final FeedCacheLocalDataSource _feedCacheLocal;
  final Map<String, int> _pageNumbers = <String, int>{};
  final Map<String, bool> _hasMoreMap = <String, bool>{};

  static const String _host = 'wallhaven.cc';
  static const String _searchPath = '/api/v1/search';
  static const int _feedTtlHours = 6;

  @override
  bool hasMoreForCategory(String categoryName) => _hasMoreMap[categoryName] ?? true;

  @override
  Future<Result<List<WallhavenWallpaper>>> fetchFeed({
    required String categoryName,
    required bool refresh,
    int categories = 100,
    int purity = 100,
  }) async {
    if (refresh) {
      _pageNumbers[categoryName] = 1;
      _hasMoreMap[categoryName] = true;
    }

    final int page = _pageNumbers[categoryName] ?? 1;
    final Uri uri = Uri.https(_host, _searchPath, <String, String>{
      'q': categoryName,
      'page': page.toString(),
      'categories': categories.toString(),
      'purity': purity.toString(),
    });

    logger.d(
      '[WallhavenWallpaperRepository] fetchFeed',
      fields: <String, Object?>{'category': categoryName, 'page': page, 'refresh': refresh},
    );

    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode != 200) {
        return await _cachedOrFailure(
          categoryName: categoryName,
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

      _pageNumbers[categoryName] = currentPage + 1;
      _hasMoreMap[categoryName] = hasMore;
      await _writeCache(
        categoryName: categoryName,
        categories: categories,
        purity: purity,
        payload: payload,
        nextPage: currentPage + 1,
        hasMore: hasMore,
      );

      logger.i(
        '[WallhavenWallpaperRepository] fetchFeed success',
        fields: <String, Object?>{'category': categoryName, 'count': walls.length},
      );
      return Result.success(walls);
    } catch (error, stackTrace) {
      final cached = await _readCached(categoryName: categoryName, categories: categories, purity: purity);
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

  static const String _toplistScope = 'toplist.1M';

  @override
  Future<Result<List<WallhavenWallpaper>>> fetchToplist({int page = 1}) async {
    final Uri uri = Uri.https(_host, _searchPath, <String, String>{
      'sorting': 'toplist',
      'topRange': '3d',
      'purity': '100',
      'categories': '100',
      'page': page.toString(),
    });

    logger.d('[WallhavenWallpaperRepository] fetchToplist', fields: <String, Object?>{'page': page});

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

      await _feedCacheLocal.write(
        source: 'wallhaven',
        scope: _toplistScope,
        ttlHours: _feedTtlHours,
        payload: <String, Object?>{'payload': jsonDecode(jsonEncode(payload.toJson()))},
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

  Future<List<WallhavenWallpaper>?> _readCachedToplist() async {
    final snapshot = await _feedCacheLocal.read(source: 'wallhaven', scope: _toplistScope);
    if (snapshot == null || snapshot.payload is! Map) return null;
    final map = toJsonMap(snapshot.payload);
    final payloadMap = toJsonMap(map['payload']);
    if (payloadMap.isEmpty) return null;
    final payload = WallhavenSearchResponseDto.fromJson(payloadMap);
    final walls = payload.data.map((item) => item.toDomain()).toList(growable: false);
    return walls.isEmpty ? null : walls;
  }

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
    required Failure failure,
  }) async {
    final cached = await _readCached(categoryName: categoryName, categories: categories, purity: purity);
    if (cached != null) {
      logger.w(
        '[WallhavenWallpaperRepository] remote status failed; returning cached snapshot',
        fields: <String, Object?>{'category': categoryName},
      );
      return Result.success(cached);
    }
    return Result.error(failure);
  }

  Future<void> _writeCache({
    required String categoryName,
    required int categories,
    required int purity,
    required WallhavenSearchResponseDto payload,
    required int nextPage,
    required bool hasMore,
  }) {
    return _feedCacheLocal.write(
      source: 'wallhaven',
      scope: _scope(categoryName: categoryName, categories: categories, purity: purity),
      ttlHours: _feedTtlHours,
      payload: <String, Object?>{
        'payload': jsonDecode(jsonEncode(payload.toJson())),
        'nextPage': nextPage,
        'hasMore': hasMore,
      },
    );
  }

  Future<List<WallhavenWallpaper>?> _readCached({
    required String categoryName,
    required int categories,
    required int purity,
  }) async {
    final snapshot = await _feedCacheLocal.read(
      source: 'wallhaven',
      scope: _scope(categoryName: categoryName, categories: categories, purity: purity),
    );
    if (snapshot == null || snapshot.payload is! Map) {
      return null;
    }

    final map = toJsonMap(snapshot.payload);
    final payloadMap = toJsonMap(map['payload']);
    if (payloadMap.isEmpty) {
      return null;
    }

    final payload = WallhavenSearchResponseDto.fromJson(payloadMap);
    final walls = payload.data.map((item) => item.toDomain()).toList(growable: false);
    if (walls.isEmpty) {
      return null;
    }

    _pageNumbers[categoryName] = (map['nextPage'] as num?)?.toInt() ?? (_pageNumbers[categoryName] ?? 1);
    _hasMoreMap[categoryName] = map['hasMore'] == true;
    return walls;
  }

  String _scope({required String categoryName, required int categories, required int purity}) {
    final normalizedCategory = categoryName.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
    return '$normalizedCategory.$categories.$purity';
  }
}
