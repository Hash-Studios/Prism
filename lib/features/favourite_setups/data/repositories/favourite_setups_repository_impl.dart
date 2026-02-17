import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/domain/repositories/favourite_setups_repository.dart';
import 'package:hive_io/hive_io.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: FavouriteSetupsRepository)
class FavouriteSetupsRepositoryImpl implements FavouriteSetupsRepository {
  FavouriteSetupsRepositoryImpl(
    this._firestoreClient,
    @Named('localFavBox') this._localFavBox,
  );

  final FirestoreClient _firestoreClient;
  final Box<dynamic> _localFavBox;

  String _collectionPath(String userId) => 'usersv2/$userId/setups';

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

  Future<List<FavouriteSetupEntity>> _read(String userId) async {
    final rows = await _firestoreClient.query<Map<String, dynamic>>(
      FirestoreQuerySpec(
        collection: _collectionPath(userId),
        sourceTag: 'favourite_setups.read',
      ),
      (data, docId) => <String, dynamic>{...data, '__docId': docId},
    );
    final items = rows.map((data) {
      final payload = <String, dynamic>{...data};
      payload.remove('__docId');
      return FavouriteSetupEntity(
        id: (payload['id'] ?? data['__docId']).toString(),
        payload: payload,
      );
    }).toList();

    items.sort((a, b) {
      final DateTime? aDate = _toDateTime(a.payload['created_at']);
      final DateTime? bDate = _toDateTime(b.payload['created_at']);
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
        final payload = <String, dynamic>{...setup.payload};
        payload['id'] = setup.id;
        payload['created_at'] ??= DateTime.now().toUtc();
        await _firestoreClient.setDoc(
          _collectionPath(userId),
          setup.id,
          payload,
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
  Future<Result<List<FavouriteSetupEntity>>> removeFavourite({
    required String userId,
    required String setupId,
  }) async {
    try {
      await _firestoreClient.deleteDoc(
        _collectionPath(userId),
        setupId,
        sourceTag: 'favourite_setups.remove',
      );
      await _localFavBox.delete(setupId);
      return Result.success(await _read(userId));
    } catch (error) {
      return Result.error(ServerFailure('Unable to remove favourite setup: $error'));
    }
  }

  @override
  Future<Result<List<FavouriteSetupEntity>>> clearAll({required String userId}) async {
    try {
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
        FirestoreQuerySpec(
          collection: _collectionPath(userId),
          sourceTag: 'favourite_setups.clear_all.read',
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      );
      for (final row in rows) {
        final String id = row['__docId']?.toString() ?? '';
        if (id.isEmpty) continue;
        await _firestoreClient.deleteDoc(
          _collectionPath(userId),
          id,
          sourceTag: 'favourite_setups.clear_all.delete',
        );
      }
      return Result.success(const <FavouriteSetupEntity>[]);
    } catch (error) {
      return Result.error(ServerFailure('Unable to clear favourite setups: $error'));
    }
  }
}
