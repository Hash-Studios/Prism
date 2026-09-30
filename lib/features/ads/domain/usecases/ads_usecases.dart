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

@lazySingleton
class ShowRewardedAdUseCase implements UseCase<AdsEntity, NoParams> {
  ShowRewardedAdUseCase(this._repository);

  final AdsRepository _repository;

  @override
  Future<Result<AdsEntity>> call(NoParams params) => _repository.showRewardedAd();
}
