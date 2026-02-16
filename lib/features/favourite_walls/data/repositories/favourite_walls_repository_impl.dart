import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteWallsRepository)
class FavouriteWallsRepositoryImpl implements FavouriteWallsRepository {
  FavouriteWallsRepositoryImpl(
    this._firestore,
    @Named('localFavBox') this._localFavBox,
  );

  final FirebaseFirestore _firestore;
  final Box<dynamic> _localFavBox;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('usersv2').doc(userId).collection('images');
  }

  Future<List<FavouriteWallEntity>> _read(String userId) async {
    final snapshot = await _collection(userId).get();
    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return FavouriteWallEntity(
        id: (data['id'] ?? doc.id).toString(),
        provider: (data['provider'] ?? '').toString(),
        payload: data,
      );
    }).toList();

    items.sort((a, b) {
      final aDate = a.payload['createdAt'];
      final bDate = b.payload['createdAt'];
      if (aDate is Timestamp && bDate is Timestamp) {
        return bDate.compareTo(aDate);
      }
      return 0;
    });

    return items;
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites(
      {required String userId}) async {
    try {
      final items = await _read(userId);
      return Result.success(items);
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to fetch favourite walls: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> toggleFavourite({
    required String userId,
    required FavouriteWallEntity wall,
  }) async {
    try {
      final docRef = _collection(userId).doc(wall.id);
      final existing = await docRef.get();
      if (existing.exists) {
        await docRef.delete();
        await _localFavBox.delete(wall.id);
      } else {
        final payload = <String, dynamic>{...wall.payload};
        payload['id'] = wall.id;
        payload['provider'] = wall.provider;
        payload['createdAt'] ??= DateTime.now().toUtc();
        await docRef.set(payload);
        await _localFavBox.put(wall.id, true);
      }

      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to toggle favourite wall: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> removeFavourite({
    required String userId,
    required String wallId,
  }) async {
    try {
      await _collection(userId).doc(wallId).delete();
      await _localFavBox.delete(wallId);
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to remove favourite wall: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteWallEntity>>> clearAll(
      {required String userId}) async {
    try {
      final snapshot = await _collection(userId).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      return Result.success(const <FavouriteWallEntity>[]);
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to clear favourite walls: $error'));
    }
  }
}
