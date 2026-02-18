import 'dart:async';
import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AdsRepository)
class AdsRepositoryImpl implements AdsRepository {
  static const int _maxFailedLoadAttempts = 3;
  static const AdRequest _request = AdRequest(
    nonPersonalizedAds: false,
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
  );

  AdsEntity _state = AdsEntity.empty;
  RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;

  @override
  Future<Result<AdsEntity>> createRewardedAd() async {
    if (_state.loadingAd || _state.adLoaded) {
      return Result.success(_state);
    }

    _state = _state.copyWith(loadingAd: true, adLoaded: false, adFailed: false);
    final completer = Completer<Result<AdsEntity>>();

    void loadWithRetry() {
      RewardedAd.load(
        adUnitId: kReleaseMode
            ? "ca-app-pub-4649644680694757/3358009164"
            : (Platform.isAndroid
                ? 'ca-app-pub-3940256099942544/5224354917'
                : 'ca-app-pub-3940256099942544/1712485313'),
        request: _request,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            logger.d('$ad loaded.');
            _rewardedAd = ad;
            _numRewardedLoadAttempts = 0;
            _state = _state.copyWith(loadingAd: false, adLoaded: true, adFailed: false);
            if (!completer.isCompleted) {
              completer.complete(Result.success(_state));
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            logger.d('RewardedAd failed to load: $error');
            _rewardedAd = null;
            _numRewardedLoadAttempts += 1;

            if (_numRewardedLoadAttempts <= _maxFailedLoadAttempts) {
              loadWithRetry();
              return;
            }

            _state = _state.copyWith(loadingAd: false, adLoaded: false, adFailed: true);
            if (!completer.isCompleted) {
              completer.complete(Result.success(_state));
            }
          },
        ),
      );
    }

    loadWithRetry();

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _state = _state.copyWith(loadingAd: false, adLoaded: false, adFailed: true);
        return Result.error(const NetworkFailure('Timed out while loading rewarded ad'));
      },
    );
  }

  @override
  Future<Result<AdsEntity>> showRewardedAd() async {
    _state = _state.copyWith(adLoaded: false, adFailed: false);
    final ad = _rewardedAd;
    if (ad == null) {
      logger.d('Warning: attempt to show rewarded before loaded.');
      return Result.error(const ValidationFailure('Rewarded ad is not loaded'));
    }

    final completer = Completer<Result<AdsEntity>>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        logger.d('ad onAdShowedFullScreenContent.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        logger.d('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        unawaited(createRewardedAd());
        if (!completer.isCompleted) {
          completer.complete(Result.success(_state));
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        logger.d('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _state = _state.copyWith(adFailed: true);
        unawaited(createRewardedAd());
        if (!completer.isCompleted) {
          completer.complete(Result.success(_state));
        }
      },
    );

    _rewardedAd = null;
    ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        logger.d('$ad with reward RewardItem(${reward.amount}, ${reward.type})');
        _state = _state.copyWith(downloadCoins: _state.downloadCoins + reward.amount);
        if (!completer.isCompleted) {
          completer.complete(Result.success(_state));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 45), onTimeout: () => Result.success(_state));
  }

  @override
  Future<Result<AdsEntity>> addReward({required num rewardAmount}) async {
    _state = _state.copyWith(downloadCoins: _state.downloadCoins + rewardAmount);
    return Result.success(_state);
  }

  @override
  Future<Result<AdsEntity>> reset() async {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _numRewardedLoadAttempts = 0;
    _state = AdsEntity.empty;
    return Result.success(_state);
  }
}
