import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/domain/repositories/user_search_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: UserSearchRepository)
class UserSearchRepositoryImpl implements UserSearchRepository {
  UserSearchRepositoryImpl(this._firestoreClient);

  final FirestoreClient _firestoreClient;

  @override
  Future<Result<List<UserSearchUser>>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Result.success(const <UserSearchUser>[]);
    }

    try {
      final rows = await _firestoreClient.query<Map<String, dynamic>>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.usersV2,
          sourceTag: 'user_search.search_users',
          filters: <FirestoreFilter>[
            FirestoreFilter(field: 'name', op: FirestoreFilterOp.isGreaterThanOrEqualTo, value: trimmed),
            FirestoreFilter(field: 'name', op: FirestoreFilterOp.isLessThanOrEqualTo, value: '$trimmed\uf8ff'),
          ],
          limit: 20,
        ),
        (data, docId) => <String, dynamic>{...data, '__docId': docId},
      );

      final users = rows
          .map((data) {
            return UserSearchUser(
              id: (data['id'] ?? data['__docId'] ?? '').toString(),
              name: (data['name'] ?? '').toString(),
              username: (data['username'] ?? '').toString(),
              email: (data['email'] ?? '').toString(),
              profilePhoto: (data['profilePhoto'] ?? '').toString(),
              coverPhoto: data['coverPhoto']?.toString(),
              bio: (data['bio'] ?? '').toString(),
              links:
                  (data['links'] as Map?)?.map((key, value) => MapEntry(key.toString(), value)) ?? <String, dynamic>{},
              followers: (data['followers'] as List?)?.toList(growable: false) ?? <dynamic>[],
              following: (data['following'] as List?)?.toList(growable: false) ?? <dynamic>[],
              premium: (data['premium'] ?? false) as bool,
            );
          })
          .toList(growable: false);

      return Result.success(users);
    } catch (error) {
      return Result.error(ServerFailure('Unable to search users: $error'));
    }
  }
}
