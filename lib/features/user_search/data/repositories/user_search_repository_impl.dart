import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/dtos/public_user_doc_dto.dart';
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
      final results = await Future.wait([_prefixQuery('name', trimmed), _prefixQuery('username', trimmed)]);

      final users = <String, UserSearchUser>{};
      for (final row in results.expand((rows) => rows)) {
        users.putIfAbsent(
          row.docId,
          () => UserSearchUser(
            id: row.doc.id.isEmpty ? row.docId : row.doc.id,
            name: row.doc.name,
            username: row.doc.username,
            email: row.doc.email,
            profilePhoto: row.doc.profilePhoto,
            followerCount: row.doc.followers.length,
          ),
        );
      }

      return Result.success(users.values.toList(growable: false));
    } catch (error) {
      return Result.error(ServerFailure('Unable to search users: $error'));
    }
  }

  Future<List<({String docId, PublicUserDocDto doc})>> _prefixQuery(String field, String prefix) {
    return _firestoreClient.query<({String docId, PublicUserDocDto doc})>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.usersV2,
        sourceTag: 'user_search.search_users_by_$field',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: field, op: FirestoreFilterOp.isGreaterThanOrEqualTo, value: prefix),
          FirestoreFilter(field: field, op: FirestoreFilterOp.isLessThanOrEqualTo, value: '$prefix\uf8ff'),
        ],
        limit: 20,
      ),
      (data, docId) => (docId: docId, doc: PublicUserDocDto.fromJson(data)),
    );
  }
}
