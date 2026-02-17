import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setup_entity.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setups_page.dart';
import 'package:Prism/features/profile_setups/domain/repositories/profile_setups_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: ProfileSetupsRepository)
class ProfileSetupsRepositoryImpl implements ProfileSetupsRepository {
  ProfileSetupsRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;
  final Map<String, String> _cursorByEmail = {};

  @override
  Future<Result<ProfileSetupsPage>> fetchProfileSetups({
    required String email,
    required bool refresh,
  }) async {
    try {
      final cursor = _cursorByEmail[email];
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.setups,
          sourceTag: 'profile_setups.fetch',
          filters: <FirestoreFilter>[
            const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: true),
            FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: email),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'created_at', descending: true)],
          limit: 8,
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
        return ProfileSetupEntity(id: (payload['id'] ?? data['__docId']).toString(), payload: payload);
      }).toList(growable: false);

      return Result.success(
        ProfileSetupsPage(
          items: items,
          hasMore: rows.length == 8,
          nextCursor: _cursorByEmail[email],
        ),
      );
    } catch (error) {
      return Result.error(ServerFailure('Unable to load profile setups: $error'));
    }
  }
}
