import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';

abstract class UserSearchRepository {
  Future<Result<List<UserSearchUser>>> searchUsers(String query);
}
