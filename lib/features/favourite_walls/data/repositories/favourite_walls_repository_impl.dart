import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:hive_io/hive_io.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteWallsRepository)
class FavouriteWallsRepositoryImpl implements FavouriteWallsRepository {
  FavouriteWallsRepositoryImpl(
    this._firestoreClient,
    @Named('localFavBox') this._localFavBox,
  );

  final FirestoreClient _firestoreClient;
  final Box<dynamic> _localFavBox;

  String _collectionPath(String userId) => 'usersv2/$userId/images';

  DateTime? _toDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    try {
      final dynamic v = value;
      return v.toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  Future<List<FavouriteWallEntity>> _read(String userId) async {
    final rows = await _firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: _collectionPath(userId),
        sourceTag: 'favourite_walls.read',
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    final items = rows.map((data) {
      final payload = <String, dynamic>{...data};
      payload.remove('__docId');
      return FavouriteWallEntity(
        id: (payload['id'] ?? data['__docId']).toString(),
        provider: (payload['provider'] ?? '').toString(),
        payload: payload,
      );
    }).toList();

    items.sort((a, b) {
      final DateTime? aDate = _toDateTime(a.payload['createdAt']);
      final DateTime? bDate = _toDateTime(b.payload['createdAt']);
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
  Future<Result<List<FavouriteWallEntity>>> toggleFavourite({
    required String userId,
    required FavouriteWallEntity wall,
  }) async {
    try {
      final existing = await _firestoreClient.getById<Map<String, dynamic>>(
        _collectionPath(userId),
        wall.id,
        (data, _) => data,
        sourceTag: 'favourite_walls.toggle.get',
      );
      if (existing != null) {
        await _firestoreClient.deleteDoc(
          _collectionPath(userId),
          wall.id,
          sourceTag: 'favourite_walls.toggle.delete',
        );
        await _localFavBox.delete(wall.id);
      } else {
        final payload = <String, dynamic>{...wall.payload};
        payload['id'] = wall.id;
        payload['provider'] = wall.provider;
        payload['createdAt'] ??= DateTime.now().toUtc();
        await _firestoreClient.setDoc(
          _collectionPath(userId),
          wall.id,
          payload,
          sourceTag: 'favourite_walls.toggle.set',
        );
        await _localFavBox.put(wall.id, true);
      }

      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to toggle favourite wall: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> removeFavourite({
    required String userId,
    required String wallId,
  }) async {
    try {
      await _firestoreClient.deleteDoc(
        _collectionPath(userId),
        wallId,
        sourceTag: 'favourite_walls.remove',
      );
      await _localFavBox.delete(wallId);
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to remove favourite wall: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> clearAll({required String userId}) async {
    try {
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
        FirestoreQuerySpec(
          collection: _collectionPath(userId),
          sourceTag: 'favourite_walls.clear_all.read',
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      );
      for (final row in rows) {
        final String id = row['__docId']?.toString() ?? '';
        if (id.isEmpty) continue;
        await _firestoreClient.deleteDoc(
          _collectionPath(userId),
          id,
          sourceTag: 'favourite_walls.clear_all.delete',
        );
      }
      return Result.success(const <FavouriteWallEntity>[]);
    } catch (error) {
      return Result.error(ServerFailure('Unable to clear favourite walls: $error'));
    }
  }
}
