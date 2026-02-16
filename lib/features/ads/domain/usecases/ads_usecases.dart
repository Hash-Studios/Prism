import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class CreateRewardedAdUseCase implements UseCase<AdsEntity, NoParams> {
  CreateRewardedAdUseCase(this._repository);

  final AdsRepository _repository;

  @override
  Future<Result<AdsEntity>> call(NoParams params) => _repository.createRewardedAd();
}

class AddRewardParams {
  const AddRewardParams({required this.rewardAmount});

  final num rewardAmount;
}

@lazySingleton
class AddRewardUseCase implements UseCase<AdsEntity, AddRewardParams> {
  AddRewardUseCase(this._repository);

  final AdsRepository _repository;

  @override
  Future<Result<AdsEntity>> call(AddRewardParams params) => _repository.addReward(rewardAmount: params.rewardAmount);
}

@lazySingleton
class ResetAdsUseCase implements UseCase<AdsEntity, NoParams> {
  ResetAdsUseCase(this._repository);

  final AdsRepository _repository;

  @override
  Future<Result<AdsEntity>> call(NoParams params) => _repository.reset();
}
