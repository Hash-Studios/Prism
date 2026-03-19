import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/ads/domain/entities/ads_entity.dart';

abstract class AdsRepository {
  Future<Result<AdsEntity>> createRewardedAd();

  Future<Result<AdsEntity>> showRewardedAd();

  Future<Result<AdsEntity>> addReward({required num rewardAmount});

  Future<Result<AdsEntity>> reset();
}
