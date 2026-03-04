import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
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
  WallhavenWallpaperRepositoryImpl();

  final Map<String, int> _pageNumbers = <String, int>{};
  final Map<String, bool> _hasMoreMap = <String, bool>{};

  static const String _host = 'wallhaven.cc';
  static const String _searchPath = '/api/v1/search';

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
        return Result.error(
          ServerFailure(
            'WallHaven feed request failed (${response.statusCode}): ${response.reasonPhrase ?? 'unknown'}',
          ),
        );
      }

      final Map<String, dynamic> decoded = json.decode(response.body) as Map<String, dynamic>;
      final WallhavenSearchResponseDto payload = WallhavenSearchResponseDto.fromJson(decoded);
      final int currentPage = payload.meta?.currentPage ?? page;
      final int lastPage = payload.meta?.lastPage ?? currentPage;
      final bool hasMore = currentPage < lastPage;

      final List<WallhavenWallpaper> walls = payload.data.map((item) => item.toDomain()).toList(growable: false);

      _pageNumbers[categoryName] = currentPage + 1;
      _hasMoreMap[categoryName] = hasMore;

      logger.i(
        '[WallhavenWallpaperRepository] fetchFeed success',
        fields: <String, Object?>{'category': categoryName, 'count': walls.length},
      );
      return Result.success(walls);
    } catch (error, stackTrace) {
      logger.e('[WallhavenWallpaperRepository] fetchFeed failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch WallHaven feed: $error'));
    }
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

      final Map<String, dynamic> decoded = json.decode(response.body) as Map<String, dynamic>;
      final WallhavenSingleResponseDto payload = WallhavenSingleResponseDto.fromJson(decoded);
      return Result.success(payload.data?.toDomain());
    } catch (error, stackTrace) {
      logger.e('[WallhavenWallpaperRepository] fetchById failed', error: error, stackTrace: stackTrace);
      return Result.error(ServerFailure('Failed to fetch WallHaven wallpaper by id: $error'));
    }
  }
}
