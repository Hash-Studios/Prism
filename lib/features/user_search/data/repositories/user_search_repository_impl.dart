import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/domain/repositories/user_search_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: UserSearchRepository)
class UserSearchRepositoryImpl implements UserSearchRepository {
  UserSearchRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Result<List<UserSearchUser>>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Result.success(const <UserSearchUser>[]);
    }

    try {
      final snapshot = await _firestore
          .collection('usersv2')
          .where('name', isGreaterThanOrEqualTo: trimmed)
          .where('name', isLessThanOrEqualTo: '$trimmed\uf8ff')
          .limit(20)
          .get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return UserSearchUser(
          id: (data['id'] ?? '').toString(),
          name: (data['name'] ?? '').toString(),
          username: (data['username'] ?? '').toString(),
          email: (data['email'] ?? '').toString(),
          profilePhoto: (data['profilePhoto'] ?? '').toString(),
          premium: (data['premium'] ?? false) as bool,
        );
      }).toList(growable: false);

      return Result.success(users);
    } catch (error) {
      return Result.error(ServerFailure('Unable to search users: $error'));
    }
  }
}
