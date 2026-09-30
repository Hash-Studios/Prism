import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart';
import 'package:Prism/features/onboarding_v2/src/domain/entities/onboarding_starter_creator_entity.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FetchStarterPackUseCase {
  FetchStarterPackUseCase(this._repository);

  final OnboardingV2Repository _repository;

  Future<Result<List<OnboardingStarterCreatorEntity>>> call(NoParams params) => _repository.fetchStarterPack();
}
