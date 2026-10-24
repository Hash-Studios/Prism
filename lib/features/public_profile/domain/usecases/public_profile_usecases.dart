import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:injectable/injectable.dart';

class FetchPublicProfileWallsParams {
  const FetchPublicProfileWallsParams({required this.userId, required this.refresh});

  final String userId;
  final bool refresh;
}

@lazySingleton
class FetchPublicProfileWallsUseCase
    implements UseCase<({List<PublicProfileWallEntity> items, bool hasMore}), FetchPublicProfileWallsParams> {
  FetchPublicProfileWallsUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<({List<PublicProfileWallEntity> items, bool hasMore})>> call(FetchPublicProfileWallsParams params) {
    return _repository.fetchWalls(userId: params.userId, refresh: params.refresh);
  }
}

class FollowUserParams {
  const FollowUserParams({
    required this.currentUserId,
    required this.currentUserEmail,
    required this.targetUserId,
    required this.targetUserEmail,
  });

  final String currentUserId;
  final String currentUserEmail;
  final String targetUserId;
  final String targetUserEmail;
}

@lazySingleton
class FollowUserUseCase implements UseCase<void, FollowUserParams> {
  FollowUserUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<void>> call(FollowUserParams params) {
    return _repository.follow(
      currentUserId: params.currentUserId,
      currentUserEmail: params.currentUserEmail,
      targetUserId: params.targetUserId,
      targetUserEmail: params.targetUserEmail,
    );
  }
}

class UnfollowUserParams {
  const UnfollowUserParams({
    required this.currentUserId,
    required this.currentUserEmail,
    required this.targetUserId,
    required this.targetUserEmail,
  });

  final String currentUserId;
  final String currentUserEmail;
  final String targetUserId;
  final String targetUserEmail;
}

@lazySingleton
class UnfollowUserUseCase implements UseCase<void, UnfollowUserParams> {
  UnfollowUserUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<void>> call(UnfollowUserParams params) {
    return _repository.unfollow(
      currentUserId: params.currentUserId,
      currentUserEmail: params.currentUserEmail,
      targetUserId: params.targetUserId,
      targetUserEmail: params.targetUserEmail,
    );
  }
}

class FetchUserSummariesPageParams {
  const FetchUserSummariesPageParams({required this.userIds, required this.page});

  final List<String> userIds;
  final int page;
}

@lazySingleton
class FetchUserSummariesPageUseCase
    implements UseCase<({List<UserSummaryEntity> items, bool hasMore}), FetchUserSummariesPageParams> {
  FetchUserSummariesPageUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<({List<UserSummaryEntity> items, bool hasMore})>> call(FetchUserSummariesPageParams params) {
    return _repository.fetchUserSummariesPage(userIds: params.userIds, page: params.page);
  }
}

class SearchUsersByUsernameParams {
  const SearchUsersByUsernameParams({required this.query, required this.scopeUserIds});

  final String query;
  final List<String> scopeUserIds;
}

@lazySingleton
class SearchUsersByUsernameUseCase implements UseCase<List<UserSummaryEntity>, SearchUsersByUsernameParams> {
  SearchUsersByUsernameUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<List<UserSummaryEntity>>> call(SearchUsersByUsernameParams params) {
    return _repository.searchUsersByUsername(query: params.query, scopeUserIds: params.scopeUserIds);
  }
}
