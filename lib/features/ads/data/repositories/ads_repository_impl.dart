import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AdsRepository)
class AdsRepositoryImpl implements AdsRepository {
  static const int _maxFailedLoadAttempts = 3;
  static const Duration _loadRetryDelay = Duration(seconds: 2);
  static const Duration _loadTimeout = Duration(seconds: 30);
  static const Duration _showTimeout = Duration(seconds: 45);
  static const String _prodAdUnitId = 'ca-app-pub-4649644680694757/3358009164';
  static const String _testAndroidAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
  static const AdRequest _request = AdRequest(
    nonPersonalizedAds: false,
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
  );

  AdsEntity _state = AdsEntity.empty;
  RewardedAd? _rewardedAd;

  @override
  Future<Result<AdsEntity>> createRewardedAd() async {
    if (_state.loadingAd || _state.adLoaded) {
      return Result.success(_state);
    }

    _state = _state.copyWith(loadingAd: true, adLoaded: false, adFailed: false);
    final completer = Completer<Result<AdsEntity>>();
    int failedAttempts = 0;
    Timer? retry;
    late final Timer timeout;

    void fail(AdFailureReason reason, {bool timedOut = false}) {
      if (completer.isCompleted) return;
      retry?.cancel();
      timeout.cancel();
      _state = _state.copyWith(loadingAd: false, adLoaded: false, adFailed: true, failureReason: reason);
      unawaited(analytics.track(AdLoadResultEvent(result: 'failed', reason: reason.name)));
      completer.complete(
        timedOut ? Result.error(const NetworkFailure('Timed out while loading rewarded ad')) : Result.success(_state),
      );
    }

    timeout = Timer(_loadTimeout, () => fail(AdFailureReason.timeout, timedOut: true));

    Future<void> loadWithRetry() async {
      if (completer.isCompleted) return;
      try {
        await RewardedAd.load(
          adUnitId: kReleaseMode ? _prodAdUnitId : (Platform.isAndroid ? _testAndroidAdUnitId : _testIosAdUnitId),
          request: _request,
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (RewardedAd ad) {
              if (completer.isCompleted) {
                unawaited(ad.dispose());
                return;
              }
              retry?.cancel();
              timeout.cancel();
              logger.d('$ad loaded.');
              ad.onPaidEvent = (Ad unusedAd, double valueMicros, PrecisionType unusedPrecision, String currency) {
                final double amount = valueMicros / 1e6;
                if (amount > 0) {
                  unawaited(
                    analytics.track(
                      RevenueRecordedEvent(
                        amountUsd: currency == 'USD' ? amount : null,
                        amount: amount,
                        currency: currency,
                        source: 'admob',
                      ),
                    ),
                  );
                }
              };
              _rewardedAd = ad;
              _state = _state.copyWith(loadingAd: false, adLoaded: true, adFailed: false);
              unawaited(analytics.track(const AdLoadResultEvent(result: 'loaded')));
              if (!completer.isCompleted) {
                completer.complete(Result.success(_state));
              }
            },
            onAdFailedToLoad: (LoadAdError error) {
              if (completer.isCompleted) return;
              logger.d('RewardedAd failed to load: $error');
              _rewardedAd = null;
              failedAttempts += 1;

              if (failedAttempts <= _maxFailedLoadAttempts) {
                retry = Timer(_loadRetryDelay, () => unawaited(loadWithRetry()));
                return;
              }

              fail(_loadFailureReason(error));
            },
          ),
        );
      } catch (error, stackTrace) {
        logger.w('Rewarded ad load failed.', tag: 'Ads', error: error, stackTrace: stackTrace);
        fail(AdFailureReason.other);
      }
    }

    Future<void> request() async {
      try {
        final bool canRequestAds = await AdConsent.instance.ensure();
        if (completer.isCompleted) return;
        if (!canRequestAds) {
          logger.d('Ad consent not granted; skipping rewarded ad load.');
          fail(AdFailureReason.consent);
          return;
        }
        unawaited(
          MobileAds.instance.initialize().then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              logger.w('Mobile ads initialization failed.', tag: 'Ads', error: error, stackTrace: stackTrace);
              fail(AdFailureReason.other);
            },
          ),
        );
        await loadWithRetry();
      } catch (error, stackTrace) {
        logger.w('Ad consent failed.', tag: 'Ads', error: error, stackTrace: stackTrace);
        fail(AdFailureReason.consent);
      }
    }

    unawaited(request());
    return completer.future;
  }

  @override
  Future<Result<AdsEntity>> showRewardedAd() async {
    _state = _state.copyWith(adLoaded: false, adFailed: false, rewardEarned: false);
    final ad = _rewardedAd;
    if (ad == null) {
      logger.d('Warning: attempt to show rewarded before loaded.');
      unawaited(analytics.track(const AdShowResultEvent(result: 'failed', reason: 'not_loaded')));
      return Result.error(const ValidationFailure('Rewarded ad is not loaded'));
    }

    bool reported = false;
    void report(String result, [String? reason]) {
      if (reported) return;
      reported = true;
      unawaited(analytics.track(AdShowResultEvent(result: result, reason: reason)));
    }

    final completer = Completer<Result<AdsEntity>>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        logger.d('ad onAdShowedFullScreenContent.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        logger.d('$ad onAdDismissedFullScreenContent.');
        report('dismissed', 'closed_early');
        ad.dispose();
        unawaited(createRewardedAd());
        if (!completer.isCompleted) {
          completer.complete(Result.success(_state));
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        logger.d('$ad onAdFailedToShowFullScreenContent: $error');
        report('failed', 'show_failed');
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
        _state = _state.copyWith(rewardEarned: true);
        report('earned');
        if (!completer.isCompleted) {
          completer.complete(Result.success(_state));
        }
      },
    );

    return completer.future.timeout(
      _showTimeout,
      onTimeout: () {
        report('failed', 'timeout');
        return Result.success(_state);
      },
    );
  }

  /// Android and iOS number the same errors differently, so the no-fill code depends on the platform.
  static AdFailureReason _loadFailureReason(LoadAdError error) {
    const int networkErrorCode = 2;
    final int noFillCode = Platform.isAndroid ? 3 : 1;
    if (error.code == networkErrorCode) return AdFailureReason.offline;
    if (error.code == noFillCode) return AdFailureReason.noFill;
    return AdFailureReason.other;
  }
}
