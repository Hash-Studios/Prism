import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteWallsRepository)
class FavouriteWallsRepositoryImpl implements FavouriteWallsRepository {
  FavouriteWallsRepositoryImpl(this._firestoreClient, this._favoritesLocal);

  final FirestoreClient _firestoreClient;
  final FavoritesLocalDataSource _favoritesLocal;

  String _collectionPath(String userId) => 'usersv2/$userId/images';

  Future<List<FavouriteWallEntity>> _read(String userId) async {
    final rows = await _firestoreClient.query<_FavouriteWallRow>(
      FirestoreQuerySpec(
        collection: _collectionPath(userId),
        sourceTag: 'favourite_walls.read',
        cachePolicy: FirestoreCachePolicy.memoryFirst,
        dedupeWindowMs: 1500,
      ),
      (data, docId) => _FavouriteWallRow(docId: docId, doc: FavouriteWallDocDto.fromJson(data)),
    );
    final items = rows.map((row) => _mapFavouriteWall(row.doc, row.docId)).toList();

    items.sort((a, b) {
      final DateTime? aDate = a.createdAt;
      final DateTime? bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return items;
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async {
    try {
      final items = await _read(userId);
      return Result.success(items);
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch favourite walls: $error'));
    }
  }

  @override
  Future<Result<bool>> toggleFavourite({
    required String userId,
    required FavouriteWallEntity wall,
    required bool currentlyFavourited,
  }) async {
    try {
      if (currentlyFavourited) {
        await _firestoreClient.deleteDoc(_collectionPath(userId), wall.id, sourceTag: 'favourite_walls.toggle.delete');
        await _favoritesLocal.setWallFavourite(userId, wall.id, false);
        return Result.success(false);
      } else {
        final Map<String, dynamic> payload = _toFirestoreDoc(wall);
        await _firestoreClient.setDoc(
          _collectionPath(userId),
          wall.id,
          payload,
          sourceTag: 'favourite_walls.toggle.set',
        );
        await _favoritesLocal.setWallFavourite(userId, wall.id, true);
        return Result.success(true);
      }
    } catch (error) {
      return Result.error(ServerFailure('Unable to toggle favourite wall: $error'));
    }
  }

  FavouriteWallEntity _mapFavouriteWall(FavouriteWallDocDto dto, String docId) {
    final String id = dto.id.isNotEmpty ? dto.id : docId;
    final WallpaperSource source = WallpaperSourceX.fromWire(dto.provider);

    switch (source) {
      case WallpaperSource.prism:
        return PrismFavouriteWall(
          id: id,
          wallpaper: PrismWallpaper(
            core: WallpaperCore(
              id: id,
              source: WallpaperSource.prism,
              fullUrl: dto.url,
              thumbnailUrl: dto.thumb,
              resolution: dto.resolution.isEmpty ? null : dto.resolution,
              sizeBytes: int.tryParse(dto.size),
              authorName: dto.photographer.isEmpty ? null : dto.photographer,
              category: dto.category.isEmpty ? null : dto.category,
              createdAt: dto.createdAt,
            ),
            collections: dto.collections.isEmpty ? null : dto.collections,
          ),
        );
      case WallpaperSource.wallhaven:
        return WallhavenFavouriteWall(
          id: id,
          wallpaper: WallhavenWallpaper(
            core: WallpaperCore(
              id: id,
              source: WallpaperSource.wallhaven,
              fullUrl: dto.url,
              thumbnailUrl: dto.thumb,
              resolution: dto.resolution.isEmpty ? null : dto.resolution,
              sizeBytes: int.tryParse(dto.size),
              category: dto.category.isEmpty ? null : dto.category,
              createdAt: dto.createdAt,
            ),
            views: int.tryParse(dto.views),
            favorites: int.tryParse(dto.fav),
            tags: dto.collections.isEmpty ? null : dto.collections,
          ),
        );
      case WallpaperSource.pexels:
        return PexelsFavouriteWall(
          id: id,
          wallpaper: PexelsWallpaper(
            core: WallpaperCore(
              id: id,
              source: WallpaperSource.pexels,
              fullUrl: dto.url,
              thumbnailUrl: dto.thumb,
              resolution: dto.resolution.isEmpty ? null : dto.resolution,
              sizeBytes: int.tryParse(dto.size),
              authorName: dto.photographer.isEmpty ? null : dto.photographer,
              category: dto.category.isEmpty ? null : dto.category,
              createdAt: dto.createdAt,
            ),
            photographer: dto.photographer.isEmpty ? null : dto.photographer,
            src: PexelsSrc(original: dto.url, medium: dto.thumb),
          ),
        );
      case WallpaperSource.downloaded:
      case WallpaperSource.unknown:
        return LegacyFavouriteWall(
          id: id,
          source: source,
          legacyPayload: <String, Object?>{
            'id': id,
            'provider': dto.provider,
            'url': dto.url,
            'thumb': dto.thumb,
            'category': dto.category,
            'views': dto.views,
            'resolution': dto.resolution,
            'fav': dto.fav,
            'size': dto.size,
            'photographer': dto.photographer,
            'collections': dto.collections,
            'createdAt': dto.createdAt,
          },
        );
    }
  }

  Map<String, dynamic> _toFirestoreDoc(FavouriteWallEntity wall) {
    final Map<String, dynamic> doc;
    switch (wall) {
      case PrismFavouriteWall():
        doc = <String, dynamic>{
          'id': wall.id,
          'url': wall.fullUrl,
          'thumb': wall.thumbnailUrl,
          'provider': wall.source.legacyProviderString,
          if (wall.wallpaper.core.category != null) 'category': wall.wallpaper.core.category,
          'views': '',
          if (wall.wallpaper.core.resolution != null) 'resolution': wall.wallpaper.core.resolution,
          'fav': '',
          if (wall.wallpaper.core.sizeBytes != null) 'size': wall.wallpaper.core.sizeBytes.toString(),
          if (wall.wallpaper.core.authorName != null) 'photographer': wall.wallpaper.core.authorName,
          if (wall.wallpaper.collections != null) 'collections': wall.wallpaper.collections,
          'createdAt': wall.createdAt ?? DateTime.now().toUtc(),
        };
      case WallhavenFavouriteWall():
        doc = <String, dynamic>{
          'id': wall.id,
          'url': wall.fullUrl,
          'thumb': wall.thumbnailUrl,
          'provider': wall.source.legacyProviderString,
          if (wall.wallpaper.core.category != null) 'category': wall.wallpaper.core.category,
          if (wall.wallpaper.views != null) 'views': wall.wallpaper.views.toString(),
          if (wall.wallpaper.core.resolution != null) 'resolution': wall.wallpaper.core.resolution,
          if (wall.wallpaper.favorites != null) 'fav': wall.wallpaper.favorites.toString(),
          if (wall.wallpaper.core.sizeBytes != null) 'size': wall.wallpaper.core.sizeBytes.toString(),
          'photographer': '',
          if (wall.wallpaper.tags != null) 'collections': wall.wallpaper.tags,
          'createdAt': DateTime.now().toUtc(),
        };
      case PexelsFavouriteWall():
        doc = <String, dynamic>{
          'id': wall.id,
          'url': wall.fullUrl,
          'thumb': wall.thumbnailUrl,
          'provider': wall.source.legacyProviderString,
          if (wall.wallpaper.core.category != null) 'category': wall.wallpaper.core.category,
          'views': '',
          if (wall.wallpaper.core.resolution != null) 'resolution': wall.wallpaper.core.resolution,
          'fav': '',
          if (wall.wallpaper.core.sizeBytes != null) 'size': wall.wallpaper.core.sizeBytes.toString(),
          if (wall.wallpaper.photographer != null) 'photographer': wall.wallpaper.photographer,
          'createdAt': DateTime.now().toUtc(),
        };
      case LegacyFavouriteWall():
        final Map<String, dynamic> base = Map<String, dynamic>.fromEntries(
          wall.legacyPayload.entries.map((e) => MapEntry<String, dynamic>(e.key, e.value)),
        );
        base['id'] = wall.id;
        base['provider'] = wall.source.legacyProviderString;
        base['createdAt'] ??= DateTime.now().toUtc();
        doc = base;
    }
    return doc;
  }

  @override
  Future<Result<bool>> removeFavourite({required String userId, required String wallId}) async {
    try {
      await _firestoreClient.deleteDoc(_collectionPath(userId), wallId, sourceTag: 'favourite_walls.remove');
      await _favoritesLocal.setWallFavourite(userId, wallId, false);
      return Result.success(true);
    } catch (error) {
      return Result.error(ServerFailure('Unable to remove favourite wall: $error'));
    }
  }

  @override
  Future<Result<bool>> clearAll({required String userId, required List<String> wallIds}) async {
    try {
      for (final String rawId in wallIds) {
        final String id = rawId.trim();
        if (id.isEmpty) continue;
        await _firestoreClient.deleteDoc(_collectionPath(userId), id, sourceTag: 'favourite_walls.clear_all.delete');
        await _favoritesLocal.setWallFavourite(userId, id, false);
      }
      return Result.success(true);
    } catch (error) {
      return Result.error(ServerFailure('Unable to clear favourite walls: $error'));
    }
  }
}

class _FavouriteWallRow {
  const _FavouriteWallRow({required this.docId, required this.doc});

  final String docId;
  final FavouriteWallDocDto doc;
}
