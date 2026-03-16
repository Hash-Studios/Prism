import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/pexels_feed/data/dtos/pexels_dtos.dart';
import 'package:Prism/features/pexels_feed/data/mappers/pexels_dto_mapper.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

@LazySingleton(as: PexelsWallpaperRepository)
class PexelsWallpaperRepositoryImpl implements PexelsWallpaperRepository {
  PexelsWallpaperRepositoryImpl(this._feedCacheLocal);

  final FeedCacheLocalDataSource _feedCacheLocal;
  final Map<String, int> _pageNumbers = <String, int>{};
  final Map<String, bool> _hasMoreMap = <String, bool>{};

  static const String _host = 'api.pexels.com';
  static const String _searchPath = '/v1/search';
  static const String _curatedPath = '/v1/curated';
  static const String _photosPath = '/v1/photos';
  static const int _feedTtlHours = 6;

  @override
  bool hasMoreForCategory(String categoryName) => _hasMoreMap[categoryName] ?? true;

  @override
  Future<Result<List<PexelsWallpaper>>> fetchFeed({required String categoryName, required bool refresh}) async {
    if (refresh) {
      _pageNumbers[categoryName] = 1;
      _hasMoreMap[categoryName] = true;
    }

    final int page = _pageNumbers[categoryName] ?? 1;
    final bool isCurated = categoryName == 'Curated';
    final String? colorHex = _parseColorCategory(categoryName);
    final Uri uri = isCurated
        ? Uri.https(_host, _curatedPath, <String, String>{'per_page': '24', 'page': page.toString()})
        : Uri.https(_host, _searchPath, <String, String>{
            if (colorHex != null) 'color': colorHex else 'query': categoryName,
            'per_page': '80',
            'page': page.toString(),
          });

    logger.d(
      '[PexelsWallpaperRepository] fetchFeed',
      fields: <String, Object?>{'category': categoryName, 'page': page, 'refresh': refresh},
    );

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

      final Map<String, dynamic> decoded = json.decode(response.body) as Map<String, dynamic>;
      final PexelsSearchResponseDto payload = PexelsSearchResponseDto.fromJson(decoded);
      final int currentPage = payload.page == 0 ? page : payload.page;
      final int totalPages = payload.perPage > 0 ? (payload.totalResults / payload.perPage).ceil() : currentPage;
      final bool hasMore = totalPages == 0 ? payload.photos.isNotEmpty : currentPage < totalPages;

      final List<PexelsWallpaper> walls = payload.photos.map((item) => item.toDomain()).toList(growable: false);

      _pageNumbers[categoryName] = currentPage + 1;
      _hasMoreMap[categoryName] = hasMore;
      await _writeCache(categoryName: categoryName, payload: payload, nextPage: currentPage + 1, hasMore: hasMore);

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

      final Map<String, dynamic> decoded = json.decode(response.body) as Map<String, dynamic>;
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

  Future<void> _writeCache({
    required String categoryName,
    required PexelsSearchResponseDto payload,
    required int nextPage,
    required bool hasMore,
  }) {
    return _feedCacheLocal.write(
      source: 'pexels',
      scope: _scope(categoryName),
      ttlHours: _feedTtlHours,
      payload: <String, Object?>{'payload': payload.toJson(), 'nextPage': nextPage, 'hasMore': hasMore},
    );
  }

  Future<List<PexelsWallpaper>?> _readCached({required String categoryName}) async {
    final snapshot = await _feedCacheLocal.read(source: 'pexels', scope: _scope(categoryName));
    if (snapshot == null || snapshot.payload is! Map) {
      return null;
    }

    final map = _asMap(snapshot.payload);
    final payloadMap = _asMap(map['payload']);
    if (payloadMap.isEmpty) {
      return null;
    }

    final payload = PexelsSearchResponseDto.fromJson(payloadMap);
    final walls = payload.photos.map((item) => item.toDomain()).toList(growable: false);
    if (walls.isEmpty) {
      return null;
    }

    _pageNumbers[categoryName] = (map['nextPage'] as num?)?.toInt() ?? (_pageNumbers[categoryName] ?? 1);
    _hasMoreMap[categoryName] = map['hasMore'] == true;
    return walls;
  }

  String _scope(String categoryName) {
    return categoryName.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
  }

  /// Parses "color: ff0000" style category into Pexels color param (hex without #).
  /// Returns null if not a color search.
  static String? _parseColorCategory(String categoryName) {
    const String prefix = 'color: ';
    if (!categoryName.startsWith(prefix)) return null;
    final String hex = categoryName.substring(prefix.length).trim().replaceFirst(RegExp('^#'), '');
    if (hex.length == 6 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
      return '#${hex.toLowerCase()}';
    }
    return null;
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
