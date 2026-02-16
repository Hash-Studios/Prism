import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_page.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:injectable/injectable.dart';

class FetchPublicProfileParams {
  const FetchPublicProfileParams({required this.email});

  final String email;
}

@lazySingleton
class FetchPublicProfileUseCase implements UseCase<PublicProfileEntity, FetchPublicProfileParams> {
  FetchPublicProfileUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<PublicProfileEntity>> call(FetchPublicProfileParams params) {
    return _repository.fetchProfile(email: params.email);
  }
}

class FetchPublicProfileWallsParams {
  const FetchPublicProfileWallsParams({required this.email, required this.refresh});

  final String email;
  final bool refresh;
}

@lazySingleton
class FetchPublicProfileWallsUseCase
    implements UseCase<PublicProfilePage<PublicProfileWallEntity>, FetchPublicProfileWallsParams> {
  FetchPublicProfileWallsUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<PublicProfilePage<PublicProfileWallEntity>>> call(
    FetchPublicProfileWallsParams params,
  ) {
    return _repository.fetchWalls(email: params.email, refresh: params.refresh);
  }
}

class FetchPublicProfileSetupsParams {
  const FetchPublicProfileSetupsParams({required this.email, required this.refresh});

  final String email;
  final bool refresh;
}

@lazySingleton
class FetchPublicProfileSetupsUseCase
    implements UseCase<PublicProfilePage<PublicProfileSetupEntity>, FetchPublicProfileSetupsParams> {
  FetchPublicProfileSetupsUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<PublicProfilePage<PublicProfileSetupEntity>>> call(
    FetchPublicProfileSetupsParams params,
  ) {
    return _repository.fetchSetups(email: params.email, refresh: params.refresh);
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
class FollowUserUseCase implements UseCase<PublicProfileEntity, FollowUserParams> {
  FollowUserUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<PublicProfileEntity>> call(FollowUserParams params) {
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
class UnfollowUserUseCase implements UseCase<PublicProfileEntity, UnfollowUserParams> {
  UnfollowUserUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<PublicProfileEntity>> call(UnfollowUserParams params) {
    return _repository.unfollow(
      currentUserId: params.currentUserId,
      currentUserEmail: params.currentUserEmail,
      targetUserId: params.targetUserId,
      targetUserEmail: params.targetUserEmail,
    );
  }
}

class UpdatePublicProfileLinksParams {
  const UpdatePublicProfileLinksParams({required this.userId, required this.links});

  final String userId;
  final Map<String, String> links;
}

@lazySingleton
class UpdatePublicProfileLinksUseCase implements UseCase<PublicProfileEntity, UpdatePublicProfileLinksParams> {
  UpdatePublicProfileLinksUseCase(this._repository);

  final PublicProfileRepository _repository;

  @override
  Future<Result<PublicProfileEntity>> call(UpdatePublicProfileLinksParams params) {
    return _repository.updateLinks(userId: params.userId, links: params.links);
  }
}
