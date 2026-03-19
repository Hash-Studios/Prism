import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:injectable/injectable.dart';

class OnboardingCreatorFollowParams {
  const OnboardingCreatorFollowParams.creator({required this.userId, required this.email, required this.name});

  final String userId;
  final String email;
  final String name;
}

class FollowStarterPackParams {
  const FollowStarterPackParams({required this.creators});

  final List<OnboardingCreatorFollowParams> creators;
}

@lazySingleton
class FollowStarterPackUseCase {
  FollowStarterPackUseCase(this._repository);

  final OnboardingV2Repository _repository;

  Future<Result<void>> call(FollowStarterPackParams params) {
    final entities = params.creators
        .map(
          (c) => OnboardingStarterCreatorEntity(
            userId: c.userId,
            email: c.email,
            name: c.name,
            photoUrl: '',
            previewUrls: const [],
            rank: 0,
            bio: '',
            followerCount: 0,
          ),
        )
        .toList();

    return _repository.followCreators(
      currentUserId: app_state.prismUser.id,
      currentUserEmail: app_state.prismUser.email,
      creators: entities,
    );
  }
}
