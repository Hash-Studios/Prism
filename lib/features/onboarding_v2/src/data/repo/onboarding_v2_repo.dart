import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';

class OnboardingUserStatus {
  const OnboardingUserStatus({required this.hasInterests, required this.hasFollows, this.completed = false});

  @override
  String toString() =>
      'OnboardingUserStatus(hasInterests: $hasInterests, hasFollows: $hasFollows, completed: $completed)';

  final bool hasInterests;
  final bool hasFollows;

  /// The server has `onboardingV2.completed == true` for this user.
  final bool completed;
}

abstract class OnboardingV2Repository {
  Future<Result<List<OnboardingStarterCreatorEntity>>> fetchStarterPack();

  Future<Result<void>> saveInterests({required String userId, required List<String> interests});

  /// Joins the interests a guest picked on this device with the account. The account wins when it already has
  /// enough interests, and the device copy follows it. Otherwise the device picks go to the account.
  Future<Result<void>> syncLocalInterests({required String userId});

  Future<Result<void>> followCreators({
    required String currentUserId,
    required String currentUserEmail,
    required List<OnboardingStarterCreatorEntity> creators,
  });

  Future<Result<void>> completeOnboarding({required String userId});

  Future<Result<OnboardingUserStatus>> fetchUserCompletionStatus({required String userId});
}
