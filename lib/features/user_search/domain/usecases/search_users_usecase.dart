import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/domain/repositories/user_search_repository.dart';
import 'package:injectable/injectable.dart';

class SearchUsersParams {
  const SearchUsersParams({required this.query});

  final String query;
}

@lazySingleton
class SearchUsersUseCase
    implements UseCase<List<UserSearchUser>, SearchUsersParams> {
  SearchUsersUseCase(this._repository);

  final UserSearchRepository _repository;

  @override
  Future<Result<List<UserSearchUser>>> call(SearchUsersParams params) =>
      _repository.searchUsers(params.query);
}
