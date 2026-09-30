import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_setups/domain/repositories/favourite_setups_repository.dart';
import 'package:Prism/features/setups/data/mappers/setup_doc_mapper.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteSetupsRepository)
class FavouriteSetupsRepositoryImpl implements FavouriteSetupsRepository {
  FavouriteSetupsRepositoryImpl(this._firestoreClient, this._favoritesLocal);

  final FirestoreClient _firestoreClient;
  final FavoritesLocalDataSource _favoritesLocal;

  String _collectionPath(String userId) => 'usersv2/$userId/setups';

  Future<List<SetupEntity>> _read(String userId) async {
    final rows = await _firestoreClient.query<SetupEntity>(
      FirestoreQuerySpec(collection: _collectionPath(userId), sourceTag: 'favourite_setups.read'),
      (data, docId) => SetupDocDto.fromJson(data).toSetupEntity(docId),
    );
    final items = rows.toList();

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
  Future<Result<List<SetupEntity>>> fetchFavourites({required String userId}) async {
    try {
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to fetch favourite setups: $error'));
    }
  }

  @override
  Future<Result<List<SetupEntity>>> toggleFavourite({required String userId, required SetupEntity setup}) async {
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
        await _favoritesLocal.setSetupFavourite(userId, setup.id, false);
      } else {
        await _firestoreClient.setDoc(
          _collectionPath(userId),
          setup.id,
          setup.toFirestoreMap(),
          sourceTag: 'favourite_setups.toggle.set',
        );
        await _favoritesLocal.setSetupFavourite(userId, setup.id, true);
      }
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to toggle favourite setup: $error'));
    }
  }
}
