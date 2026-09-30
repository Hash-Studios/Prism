import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class CompleteOnboardingV2UseCase {
  CompleteOnboardingV2UseCase(this._repository);

  final OnboardingV2Repository _repository;

  Future<Result<void>> call(NoParams params) => _repository.completeOnboarding(userId: app_state.prismUser.id);
}
