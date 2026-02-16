import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/domain/repositories/favourite_setups_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteSetupsRepository)
class FavouriteSetupsRepositoryImpl implements FavouriteSetupsRepository {
  FavouriteSetupsRepositoryImpl(
    this._firestore,
    @Named('localFavBox') this._localFavBox,
  );

  final FirebaseFirestore _firestore;
  final Box<dynamic> _localFavBox;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('usersv2').doc(userId).collection('setups');
  }

  Future<List<FavouriteSetupEntity>> _read(String userId) async {
    final snapshot = await _collection(userId).get();
    final items = snapshot.docs.map((doc) {
      final data = doc.data();
      return FavouriteSetupEntity(
        id: (data['id'] ?? doc.id).toString(),
        payload: data,
      );
    }).toList();

    items.sort((a, b) {
      final aDate = a.payload['created_at'];
      final bDate = b.payload['created_at'];
      if (aDate is Timestamp && bDate is Timestamp) {
        return bDate.compareTo(aDate);
      }
      return 0;
    });

    return items;
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> fetchFavourites(
      {required String userId}) async {
    try {
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to fetch favourite setups: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> toggleFavourite({
    required String userId,
    required FavouriteSetupEntity setup,
  }) async {
    try {
      final docRef = _collection(userId).doc(setup.id);
      final existing = await docRef.get();
      if (existing.exists) {
        await docRef.delete();
        await _localFavBox.delete(setup.id);
      } else {
        final payload = <String, dynamic>{...setup.payload};
        payload['id'] = setup.id;
        payload['created_at'] ??= DateTime.now().toUtc();
        await docRef.set(payload);
        await _localFavBox.put(setup.id, true);
      }
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to toggle favourite setup: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> removeFavourite({
    required String userId,
    required String setupId,
  }) async {
    try {
      await _collection(userId).doc(setupId).delete();
      await _localFavBox.delete(setupId);
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to remove favourite setup: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> clearAll(
      {required String userId}) async {
    try {
      final snapshot = await _collection(userId).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      return Result.success(const <FavouriteSetupEntity>[]);
    } catch (error) {
      return Result.error(
          ServerFailure('Unable to clear favourite setups: $error'));
    }
  }
}
