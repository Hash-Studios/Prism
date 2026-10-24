import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/domain/repositories/user_search_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: UserSearchRepository)
class UserSearchRepositoryImpl implements UserSearchRepository {
  UserSearchRepositoryImpl(this._firestoreClient, this._userBlockRepository);

  final FirestoreClient _firestoreClient;
  final UserBlockRepository _userBlockRepository;

  @override
  Future<Result<List<UserSearchUser>>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Result.success(const <UserSearchUser>[]);
    }

    try {
      final List<List<({String id, String name, String username, String profilePhoto, int followerCount})>> results =
          await Future.wait(
            <Future<List<({String id, String name, String username, String profilePhoto, int followerCount})>>>[
              _prefixNameQuery(trimmed),
              _prefixUsernameQueries(trimmed),
            ],
          );
      final usernameRows = await _usernamePrefixQuery(trimmed.toLowerCase());
      final blockedResult = await _userBlockRepository.fetchBlockedUsersList();
      if (blockedResult.isFailure) return Result.error(blockedResult.failure!);
      final Set<String> blocked = blockedResult.data!.map((row) => row.blockedUid).toSet();

      final users = <String, UserSearchUser>{};
      for (final row in results.expand((rows) => rows)) {
        if (blocked.contains(row.id)) continue;
        users.putIfAbsent(
          row.id,
          () => UserSearchUser(
            id: row.id,
            name: row.name,
            username: row.username,
            profilePhoto: row.profilePhoto,
            followerCount: row.followerCount,
          ),
        );
      }

      for (final String uid in usernameRows.map((row) => row.uid)) {
        if (uid.isEmpty || blocked.contains(uid) || users.containsKey(uid)) continue;
        final Map<String, dynamic>? profile = await _firestoreClient.getById<Map<String, dynamic>>(
          FirebaseCollections.profiles,
          uid,
          (data, _) => data,
          sourceTag: 'user_search.profile_for_username',
        );
        if (profile == null) continue;
        users[uid] = UserSearchUser(
          id: uid,
          name: profile['name'] is String ? profile['name'] as String : '',
          username: profile['username'] is String ? profile['username'] as String : '',
          profilePhoto: profile['profilePhoto'] is String ? profile['profilePhoto'] as String : '',
          followerCount: profile['followerCount'] is int ? profile['followerCount'] as int : 0,
        );
      }

      return Result.success(users.values.toList(growable: false));
    } catch (error) {
      return Result.error(ServerFailure('Unable to search users: $error'));
    }
  }

  Future<List<({String id, String name, String username, String profilePhoto, int followerCount})>> _prefixNameQuery(
    String prefix,
  ) {
    return _firestoreClient.query<({String id, String name, String username, String profilePhoto, int followerCount})>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.profiles,
        sourceTag: 'user_search.search_profiles_by_name',
        filters: <FirestoreFilter>[
          FirestoreFilter(field: 'name', op: FirestoreFilterOp.isGreaterThanOrEqualTo, value: prefix),
          FirestoreFilter(field: 'name', op: FirestoreFilterOp.isLessThan, value: '$prefix\uf8ff'),
        ],
        limit: 20,
      ),
      (data, docId) => (
        id: docId,
        name: data['name'] is String ? data['name'] as String : '',
        username: data['username'] is String ? data['username'] as String : '',
        profilePhoto: data['profilePhoto'] is String ? data['profilePhoto'] as String : '',
        followerCount: data['followerCount'] is int ? data['followerCount'] as int : 0,
      ),
    );
  }

  Future<List<({String id, String name, String username, String profilePhoto, int followerCount})>>
  _prefixUsernameQueries(String prefix) async {
    final Set<String> prefixes = <String>{prefix, prefix.toLowerCase()};
    final results = await Future.wait(
      prefixes.map(
        (value) =>
            _firestoreClient.query<({String id, String name, String username, String profilePhoto, int followerCount})>(
              FirestoreQuerySpec(
                collection: FirebaseCollections.profiles,
                sourceTag: 'user_search.search_legacy_usernames',
                filters: <FirestoreFilter>[
                  FirestoreFilter(field: 'username', op: FirestoreFilterOp.isGreaterThanOrEqualTo, value: value),
                  FirestoreFilter(field: 'username', op: FirestoreFilterOp.isLessThan, value: '$value\uf8ff'),
                ],
                limit: 20,
              ),
              (data, docId) => (
                id: docId,
                name: data['name'] is String ? data['name'] as String : '',
                username: data['username'] is String ? data['username'] as String : '',
                profilePhoto: data['profilePhoto'] is String ? data['profilePhoto'] as String : '',
                followerCount: data['followerCount'] is int ? data['followerCount'] as int : 0,
              ),
            ),
      ),
    );
    return results.expand((rows) => rows).toList(growable: false);
  }

  Future<List<({String uid, String username})>> _usernamePrefixQuery(String prefix) =>
      _firestoreClient.query<({String uid, String username})>(
        FirestoreQuerySpec(
          collection: FirebaseCollections.usernames,
          sourceTag: 'user_search.search_username_registry',
          filters: <FirestoreFilter>[
            FirestoreFilter(
              field: firestoreDocumentIdField,
              op: FirestoreFilterOp.isGreaterThanOrEqualTo,
              value: prefix,
            ),
            FirestoreFilter(field: firestoreDocumentIdField, op: FirestoreFilterOp.isLessThan, value: '$prefix\uf8ff'),
          ],
          orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: firestoreDocumentIdField)],
          limit: 20,
        ),
        (data, username) => (uid: data['uid'] is String ? data['uid'] as String : '', username: username),
      );
}
