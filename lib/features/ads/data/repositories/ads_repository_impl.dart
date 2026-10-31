import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/ad_experiment_service.dart';
import 'package:Prism/features/ads/data/ad_journey.dart';
import 'package:Prism/features/ads/data/rewarded_ad_unit.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/entities/rewarded_session.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: AdsRepository)
class AdsRepositoryImpl implements AdsRepository {
  AdsRepositoryImpl() {
    AdConsent.instance.invalidationListeners.add(_invalidate);
  }
  RewardedSession? _session;
  Future<Result<AdsEntity>>? _preload;
  bool _fullscreen = false;
  int _generation = 0;
  AdJourney _journey = AdJourney('guest_download');
  void _invalidate() {
    _generation++;
    _session = null;
    final ad = _rewardedAd;
    _rewardedAd = null;
    if (ad != null) unawaited(ad.dispose());
    _state = AdsEntity.empty;
    _preload = null;
  }

  Future<Result<AdsEntity>> prepareSession(RewardedSession session, {String placement = 'rewarded_ad'}) {
    if (_fullscreen) return Future.value(Result.error(const ValidationFailure('An ad is already showing')));
    _invalidate();
    _session = session;
    _journey = AdJourney(placement, watchId: session.watchId)..record('reserved');
    return createRewardedAd();
  }

  static const int _maxFailedLoadAttempts = 3;
  static const Duration _loadRetryDelay = Duration(seconds: 2);
  static const Duration _loadTimeout = Duration(seconds: 30);
  static const AdRequest _request = AdRequest(
    nonPersonalizedAds: false,
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
  );

  AdsEntity _state = AdsEntity.empty;
  RewardedAd? _rewardedAd;

  @override
  Future<Result<AdsEntity>> createRewardedAd() {
    if (_preload != null) return _preload!;
    final future = _createRewardedAd();
    _preload = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_preload, future)) _preload = null;
      }),
    );
    return future;
  }

  Future<Result<AdsEntity>> _createRewardedAd() async {
    final int generation = _generation;
    if (_fullscreen || (app_state.prismUser.loggedIn && _session == null)) {
      return Result.error(const ValidationFailure('Verified reward session required'));
    }
    if (_state.loadingAd || _state.adLoaded) {
      return Result.success(_state);
    }
    if (_session == null) _journey = AdJourney('guest_download');
    final journey = _journey;

    final String? adUnitId =
        (kReleaseMode ? _session?.adUnitId : null) ??
        rewardedAdUnitId(
          isRelease: kReleaseMode,
          platform: Platform.isAndroid ? TargetPlatform.android : TargetPlatform.iOS,
          iosAdUnitId: Env.normalize(Env.admobIosRewardedAdUnitId),
        );
    if (adUnitId == null) {
      logger.w('iOS rewarded ad unit is not configured.', tag: 'Ads');
      _state = _state.copyWith(loadingAd: false, adLoaded: false, adFailed: true, failureReason: AdFailureReason.other);
      unawaited(analytics.track(const AdLoadResultEvent(result: 'failed', reason: 'other')));
      return Result.error(const ValidationFailure('iOS rewarded ad unit is not configured'));
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
      if (generation != _generation) {
        completer.complete(Result.error(const ValidationFailure('Ad consent changed')));
        return;
      }
      _state = _state.copyWith(loadingAd: false, adLoaded: false, adFailed: true, failureReason: reason);
      unawaited(analytics.track(AdLoadResultEvent(result: 'failed', reason: reason.name)));
      journey.record('load_${reason.name}');
      completer.complete(
        timedOut ? Result.error(const NetworkFailure('Timed out while loading rewarded ad')) : Result.success(_state),
      );
    }

    timeout = Timer(_loadTimeout, () => fail(AdFailureReason.timeout, timedOut: true));

    Future<void> loadWithRetry() async {
      if (completer.isCompleted) return;
      if (generation != _generation) {
        fail(AdFailureReason.consent);
        return;
      }
      try {
        await RewardedAd.load(
          adUnitId: adUnitId,
          request: _request,
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (RewardedAd ad) {
              if (completer.isCompleted || generation != _generation) {
                unawaited(ad.dispose());
                fail(AdFailureReason.consent);
                return;
              }
              retry?.cancel();
              timeout.cancel();
              logger.d('$ad loaded.');
              ad.onPaidEvent = (Ad unusedAd, double valueMicros, PrecisionType unusedPrecision, String currency) {
                journey.record(
                  'paid',
                  paidValueMicros: valueMicros,
                  currency: currency,
                  precision: unusedPrecision.name,
                );
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
              journey.record('loaded');
              if (!completer.isCompleted) {
                completer.complete(Result.success(_state));
              }
            },
            onAdFailedToLoad: (LoadAdError error) {
              if (completer.isCompleted) return;
              if (generation != _generation) {
                fail(AdFailureReason.consent);
                return;
              }
              logger.d('RewardedAd failed to load: $error');
              _rewardedAd = null;
              failedAttempts += 1;

              if (failedAttempts <= _maxFailedLoadAttempts) {
                retry = Timer(_loadRetryDelay, () => unawaited(loadWithRetry()));
                return;
              }

              logger.w(
                'Rewarded ad failed to load after retries.',
                tag: 'Ads',
                fields: {'domain': error.domain, 'code': error.code, 'message': error.message},
              );
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
    if (_fullscreen) return Result.error(const ValidationFailure('An ad is already showing'));
    if (!await AdConsent.instance.canShow()) {
      _invalidate();
      return Result.error(const ValidationFailure('Ad consent changed'));
    }
    final session = _session;
    final journey = _journey;
    final int showGeneration = _generation;
    if (app_state.prismUser.loggedIn &&
        (session == null ||
            session.userId != app_state.prismUser.id ||
            DateTime.now().millisecondsSinceEpoch >= session.showBeforeMs)) {
      _invalidate();
      return Result.error(const ValidationFailure('Verified reward session required'));
    }
    _state = _state.copyWith(adLoaded: false, adFailed: false, rewardEarned: false, rewardPending: false);
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
    _fullscreen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (_) {
        journey.record('impression');
        unawaited(AdExperimentService.instance.recordFullscreen().catchError((Object _) {}));
      },
      onAdShowedFullScreenContent: (RewardedAd ad) {
        unawaited(AdExperimentService.instance.recordFullscreen().catchError((Object _) {}));
        logger.d('ad onAdShowedFullScreenContent.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        journey.record('dismissed');
        _fullscreen = false;
        _session = null;
        logger.d('$ad onAdDismissedFullScreenContent.');
        report('dismissed', 'closed_early');
        ad.dispose();
        if (session != null) unawaited(CoinsService.instance.reconcileRewardedSession());
        if (!completer.isCompleted) {
          completer.complete(Result.success(_state));
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        journey.record('show_failed');
        _fullscreen = false;
        _session = null;
        logger.d('$ad onAdFailedToShowFullScreenContent: $error');
        report('failed', 'show_failed');
        ad.dispose();
        _state = _state.copyWith(adFailed: true);
        if (!completer.isCompleted) {
          completer.complete(Result.success(_state));
        }
      },
    );

    _rewardedAd = null;
    try {
      if (session != null) {
        await ad.setServerSideOptions(
          ServerSideVerificationOptions(userId: session.userId, customData: session.customData),
        );
      }
      if (!await AdConsent.instance.canShow() ||
          showGeneration != _generation ||
          (session != null &&
              (!app_state.prismUser.loggedIn ||
                  session.userId != app_state.prismUser.id ||
                  DateTime.now().millisecondsSinceEpoch >= session.showBeforeMs))) {
        _fullscreen = false;
        await ad.dispose();
        return Result.error(const ValidationFailure('Ad authorization changed'));
      }
      if (session != null) await CoinsService.instance.markRewardedSessionShown(session);
      if (!await AdConsent.instance.canShow() ||
          showGeneration != _generation ||
          (session != null &&
              (!app_state.prismUser.loggedIn ||
                  app_state.prismUser.id != session.userId ||
                  DateTime.now().millisecondsSinceEpoch >= session.showBeforeMs))) {
        throw StateError('Reward authorization changed');
      }
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          logger.d('$ad with reward RewardItem(${reward.amount}, ${reward.type})');
          _state = _state.copyWith(rewardEarned: session == null, rewardPending: session != null);
          journey.record('sdk_reward_pending');
          report('earned');
          if (session != null) unawaited(CoinsService.instance.reconcileRewardedSession());
        },
      );
    } catch (error, stackTrace) {
      _fullscreen = false;
      _session = null;
      await ad.dispose();
      logger.w('Rewarded ad show failed.', tag: 'Ads', error: error, stackTrace: stackTrace);
      report('failed', 'show_failed');
      return Result.error(const ValidationFailure('Rewarded ad could not be shown'));
    }

    return completer.future;
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
