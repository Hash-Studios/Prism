import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
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

class FetchRelationPageParams {
  const FetchRelationPageParams({required this.profileUid, required this.kind, this.cursor});

  final String profileUid;
  final UserRelationKind kind;
  final RelationCursor? cursor;
}

@lazySingleton
class FetchRelationPageUseCase implements UseCase<RelationPage, FetchRelationPageParams> {
  FetchRelationPageUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<RelationPage>> call(FetchRelationPageParams params) {
    return _repository.fetchRelationPage(profileUid: params.profileUid, kind: params.kind, cursor: params.cursor);
  }
}

class FetchRelationIdsParams {
  const FetchRelationIdsParams({required this.profileUid, required this.kind});

  final String profileUid;
  final UserRelationKind kind;
}

@lazySingleton
class FetchRelationIdsUseCase implements UseCase<List<String>, FetchRelationIdsParams> {
  FetchRelationIdsUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<List<String>>> call(FetchRelationIdsParams params) {
    return _repository.fetchRelationIds(profileUid: params.profileUid, kind: params.kind);
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
