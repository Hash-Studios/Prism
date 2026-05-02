import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:injectable/injectable.dart';

class SaveInterestsParams {
  const SaveInterestsParams({required this.interests});

  final List<String> interests;
}

@lazySingleton
class SaveInterestsUseCase {
  SaveInterestsUseCase(this._repository);

  final OnboardingV2Repository _repository;

  Future<Result<void>> call(SaveInterestsParams params) =>
      _repository.saveInterests(userId: app_state.prismUser.id, interests: params.interests);
}
