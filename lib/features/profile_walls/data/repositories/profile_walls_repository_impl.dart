import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_wall_entity.dart';
import 'package:Prism/features/profile_walls/domain/entities/profile_walls_page.dart';
import 'package:Prism/features/profile_walls/domain/repositories/profile_walls_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileWallsRepository)
class ProfileWallsRepositoryImpl implements ProfileWallsRepository {
  ProfileWallsRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;
  final Map<String, String> _cursorByEmail = {};

  @override
  Future<Result<ProfileWallsPage>> fetchProfileWalls({required String email, required bool refresh}) async {
    try {
      final cursor = _cursorByEmail[email];
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.walls,
          sourceTag: 'profile_walls.fetch',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: 12,
          startAfterDocId: refresh ? null : cursor,
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      );
      if (rows.isNotEmpty) {
        _cursorByEmail[email] = rows.last['__docId']?.toString() ?? '';
      }

      final items = rows.map((data) {
        final payload = <String, dynamic>{...data};
        payload.remove('__docId');
        return ProfileWallEntity(id: (payload['id'] ?? data['__docId']).toString(), payload: payload);
      }).toList(growable: false);

      return Result.success(
        ProfileWallsPage(items: items, hasMore: rows.length == 12, nextCursor: _cursorByEmail[email]),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to load profile walls: $error'));
    }
  }
}
