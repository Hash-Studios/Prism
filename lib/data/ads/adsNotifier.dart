import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsNotifier extends ChangeNotifier {
  num downloadCoins = 0;
  bool loadingAd = false;
  bool adLoaded = false;
  bool adFailed = false;
  RewardedAd? rewardedAd;
  int _numRewardedLoadAttempts = 0;
  final int _maxFailedLoadAttempts = 3;
  // AdHelper({this.loadingAd = false, this.adLoaded = false, this.rewardedAd});
  static const AdRequest request = AdRequest(
    nonPersonalizedAds: false,
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
  );
  void rewardFn(num rewardAmount) {
    downloadCoins += rewardAmount;
    logger.d("Coins : ${downloadCoins.toString()}");
    notifyListeners();
  }

  Future<void> createRewardedAd() async {
    if (loadingAd == false && adLoaded == false) {
      loadingAd = true;
      await RewardedAd.load(
        adUnitId: kReleaseMode
            ? "ca-app-pub-4649644680694757/3358009164"
            : RewardedAd.testAdUnitId,
        request: request,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            logger.d('$ad loaded.');
            rewardedAd = ad;
            _numRewardedLoadAttempts = 0;
            loadingAd = false;
            adLoaded = true;
            notifyListeners();
          },
          onAdFailedToLoad: (LoadAdError error) {
            logger.d('RewardedAd failed to load: $error');
            loadingAd = false;
            rewardedAd = null;
            _numRewardedLoadAttempts += 1;
            notifyListeners();
            if (_numRewardedLoadAttempts <= _maxFailedLoadAttempts) {
              createRewardedAd();
            } else {
              adFailed = true;
              notifyListeners();
            }
          },
        ),
      );
    }
    notifyListeners();
  }

  void showRewardedAd(Function rewardFunc) {
    adLoaded = false;
    if (rewardedAd == null) {
      logger.d('Warning: attempt to show rewarded before loaded.');
      return;
    }
    rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) =>
          logger.d('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        logger.d('$ad onAdDismissedFullScreenContent.');
        ad.dispose();
        createRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        logger.d('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        createRewardedAd();
      },
    );

    rewardedAd!.show(onUserEarnedReward: (RewardedAd ad, RewardItem reward) {
      logger.d('$ad with reward $RewardItem(${reward.amount}, ${reward.type}');
      rewardFn(reward.amount);
      if (downloadCoins >= 10) rewardFunc();
    });
    rewardedAd = null;
    notifyListeners();
  }
}
