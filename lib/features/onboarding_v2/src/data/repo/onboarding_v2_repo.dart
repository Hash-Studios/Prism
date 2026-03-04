import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';

abstract class OnboardingV2Repository {
  Future<Result<List<OnboardingStarterCreatorEntity>>> fetchStarterPack();

  Future<Result<void>> saveInterests({required String userId, required List<String> interests});

  Future<Result<void>> followCreators({
    required String currentUserId,
    required String currentUserEmail,
    required List<OnboardingStarterCreatorEntity> creators,
  });

  Future<Result<void>> completeOnboarding({required String userId});
}
