import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AdsRepository)
class AdsRepositoryImpl implements AdsRepository {
  AdsEntity _state = AdsEntity.empty;

  @override
  Future<Result<AdsEntity>> createRewardedAd() async {
    _state = _state.copyWith(loadingAd: true, adLoaded: false, adFailed: false);

    // Phase-1 keeps ad mediation isolated from UI/runtime wiring.
    _state = _state.copyWith(loadingAd: false, adLoaded: true, adFailed: false);
    return Result.success(_state);
  }

  @override
  Future<Result<AdsEntity>> addReward({required num rewardAmount}) async {
    _state =
        _state.copyWith(downloadCoins: _state.downloadCoins + rewardAmount);
    return Result.success(_state);
  }

  @override
  Future<Result<AdsEntity>> reset() async {
    _state = AdsEntity.empty;
    return Result.success(_state);
  }
}
