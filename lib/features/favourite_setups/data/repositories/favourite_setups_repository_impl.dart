import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/domain/repositories/favourite_setups_repository.dart';
import 'package:hive_io/hive_io.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteSetupsRepository)
class FavouriteSetupsRepositoryImpl implements FavouriteSetupsRepository {
  FavouriteSetupsRepositoryImpl(this._firestoreClient, @Named('localFavBox') this._localFavBox);

  final FirestoreClient _firestoreClient;
  final Box<dynamic> _localFavBox;

  String _collectionPath(String userId) => 'usersv2/$userId/setups';

  Future<List<FavouriteSetupEntity>> _read(String userId) async {
    final rows = await _firestoreClient.query<_SetupRow>(
      FirestoreQuerySpec(collection: _collectionPath(userId), sourceTag: 'favourite_setups.read'),
      (data, docId) => _SetupRow(docId: docId, doc: SetupDocDto.fromJson(data)),
    );

    final items = rows.map((row) => _mapSetup(row.doc, row.docId)).toList();

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
  Future<Result<List<FavouriteSetupEntity>>> fetchFavourites({required String userId}) async {
    try {
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch favourite setups: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> toggleFavourite({
    required String userId,
    required FavouriteSetupEntity setup,
  }) async {
    try {
      final existing = await _firestoreClient.getById<Map<String, dynamic>>(
        _collectionPath(userId),
        setup.id,
        (data, _) => data,
        sourceTag: 'favourite_setups.toggle.get',
      );
      if (existing != null) {
        await _firestoreClient.deleteDoc(
          _collectionPath(userId),
          setup.id,
          sourceTag: 'favourite_setups.toggle.delete',
        );
        await _localFavBox.delete(setup.id);
      } else {
        await _firestoreClient.setDoc(
          _collectionPath(userId),
          setup.id,
          _toFirestoreDoc(setup),
          sourceTag: 'favourite_setups.toggle.set',
        );
        await _localFavBox.put(setup.id, true);
      }
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to toggle favourite setup: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> removeFavourite({required String userId, required String setupId}) async {
    try {
      await _firestoreClient.deleteDoc(_collectionPath(userId), setupId, sourceTag: 'favourite_setups.remove');
      await _localFavBox.delete(setupId);
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to remove favourite setup: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> clearAll({required String userId}) async {
    try {
      final rows = await _firestoreClient.query<String>(
        FirestoreQuerySpec(collection: _collectionPath(userId), sourceTag: 'favourite_setups.clear_all.read'),
        (_, docId) => docId,
      );
      for (final String id in rows) {
        if (id.isEmpty) continue;
        await _firestoreClient.deleteDoc(_collectionPath(userId), id, sourceTag: 'favourite_setups.clear_all.delete');
      }
      return Result.success(const <FavouriteSetupEntity>[]);
    } catch (error) {
      return Result.error(ServerFailure('Unable to clear favourite setups: $error'));
    }
  }

  FavouriteSetupEntity _mapSetup(SetupDocDto dto, String docId) {
    return FavouriteSetupEntity(
      id: dto.id.isNotEmpty ? dto.id : docId,
      by: dto.by,
      icon: dto.icon,
      iconUrl: dto.iconUrl,
      createdAt: dto.createdAt,
      desc: dto.desc,
      email: dto.email,
      image: dto.image,
      name: dto.name,
      userPhoto: dto.userPhoto,
      wallId: dto.wallId,
      source: WallpaperSourceX.fromWire(dto.wallpaperProvider),
      wallpaperThumb: dto.wallpaperThumb,
      wallpaperUrl: dto.wallpaperUrl,
      widget: dto.widget,
      widget2: dto.widget2,
      widgetUrl: dto.widgetUrl,
      widgetUrl2: dto.widgetUrl2,
      link: dto.link,
      review: dto.review,
      resolution: dto.resolution,
      size: dto.size,
    );
  }

  Map<String, dynamic> _toFirestoreDoc(FavouriteSetupEntity setup) {
    return <String, dynamic>{
      'id': setup.id,
      'by': setup.by,
      'icon': setup.icon,
      'icon_url': setup.iconUrl,
      'created_at': setup.createdAt ?? DateTime.now().toUtc(),
      'desc': setup.desc,
      'email': setup.email,
      'image': setup.image,
      'name': setup.name,
      'userPhoto': setup.userPhoto,
      'wall_id': setup.wallId,
      'wallpaper_provider': setup.source?.legacyProviderString,
      'wallpaper_thumb': setup.wallpaperThumb,
      'wallpaper_url': setup.wallpaperUrl,
      'widget': setup.widget,
      'widget2': setup.widget2,
      'widget_url': setup.widgetUrl,
      'widget_url2': setup.widgetUrl2,
      'link': setup.link,
      'review': setup.review,
      'resolution': setup.resolution,
      'size': setup.size,
    };
  }
}

class _SetupRow {
  const _SetupRow({required this.docId, required this.doc});

  final String docId;
  final SetupDocDto doc;
}
