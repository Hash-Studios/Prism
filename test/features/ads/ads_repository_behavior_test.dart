import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/debug/in_memory_log_sink.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ads/biz/coin_gate_port.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/ad_experiment_service.dart';
import 'package:Prism/features/ads/data/repositories/ads_repository_impl.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/entities/rewarded_session.dart';
import 'package:Prism/features/ads/domain/repositories/ads_repository.dart';
import 'package:Prism/logger/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show AdMessageCodec;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/wait_for_real_io.dart';

class _ThrowingConsent extends AdConsent {
  @override
  Future<bool> ensure() async => throw StateError('consent unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = 'plugins.flutter.io/google_mobile_ads';
  late AdConsent originalConsent;
  late FakeAppAnalytics analytics;
  late AdsRepositoryImpl repository;
  late List<String> nativeMethods;
  late List<int> loadIds;
  late List<int> disposedIds;
  late bool throwLoad;
  final codec = StandardMethodCodec(AdMessageCodec());

  Future<void> adEvent(int id, String event, {LoadAdError? error, RewardItem? reward}) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      channel,
      codec.encodeMethodCall(
        MethodCall('onAdEvent', <String, Object?>{
          'adId': id,
          'eventName': event,
          if (error != null) 'loadAdError': error,
          if (reward != null) 'rewardItem': reward,
        }),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  void consent(bool granted) {
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => granted,
    );
  }

  setUp(() {
    originalConsent = AdConsent.instance;
    consent(true);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    repository = AdsRepositoryImpl();
    nativeMethods = [];
    loadIds = [];
    disposedIds = [];
    throwLoad = false;
    InMemoryLogSink.instance.clear();
    messenger.setMockMessageHandler(channel, (ByteData? message) async {
      final call = codec.decodeMethodCall(message);
      final method = call.method;
      nativeMethods.add(method);
      if (method == 'loadRewardedAd') {
        loadIds.add((call.arguments as Map)['adId'] as int);
        if (throwLoad) return codec.encodeErrorEnvelope(code: 'native_load_failed');
      }
      if (method == 'disposeAd') disposedIds.add((call.arguments as Map)['adId'] as int);
      if (method == 'MobileAds#initialize') return Completer<ByteData?>().future;
      return const StandardMethodCodec().encodeSuccessEnvelope(null);
    });
  });

  tearDown(() {
    messenger.setMockMessageHandler(channel, null);
    AdConsent.instance = originalConsent;
    AnalyticsRuntime.reset();
  });

  testWidgets('refused consent returns a failed state without requesting an ad', (tester) async {
    consent(false);
    final result = await repository.createRewardedAd();
    expect(result.isSuccess, true);
    expect(result.data?.failureReason, AdFailureReason.consent);
    expect(result.data?.adFailed, true);
    expect(result.data?.loadingAd, false);
    expect(result.data?.adLoaded, false);
    expect(nativeMethods, isEmpty);
    expect(analytics.events.whereType<AdLoadResultEvent>().single.toWireParameters(), {
      'result': 'failed',
      'reason': 'consent',
    });
  });

  testWidgets('showing without a loaded ad returns a validation failure', (tester) async {
    final result = await repository.showRewardedAd();
    expect(result.isFailure, true);
    expect(result.failure, isA<ValidationFailure>());
    expect(result.failure?.message, 'Rewarded ad is not loaded');
    expect(analytics.events.whereType<AdShowResultEvent>().single.toWireParameters(), {
      'result': 'failed',
      'reason': 'not_loaded',
    });
  });

  testWidgets('concurrent preloads share the final loaded result', (tester) async {
    final first = repository.createRewardedAd();
    final second = repository.createRewardedAd();
    expect(identical(first, second), isTrue);
    await tester.pump();
    expect(loadIds, hasLength(1));
    await adEvent(loadIds.single, 'onAdLoaded');
    expect((await first).data?.adLoaded, isTrue);
    expect((await second).data?.adLoaded, isTrue);
  });

  testWidgets('signed-in show configures SSV on the exact ad before showing', (tester) async {
    final owner = app_state.prismUser;
    await CoinsTestBackend().install();
    addTearDown(() async {
      app_state.prismUser = owner;
      await getIt.reset();
    });
    final loaded = repository.prepareSession(
      RewardedSession(
        sessionId: 'session',
        userId: app_state.prismUser.id,
        customData: 'token',
        adUnitId: 'server-unit',
        watchId: 'watch',
        rewardCoins: 10,
        adsRemaining: 3,
        placement: 'download',
        callbackBeforeMs: DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
        showBeforeMs: DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      ),
    );
    await tester.pump();
    final id = loadIds.single;
    await adEvent(id, 'onAdLoaded');
    await loaded;
    final shown = repository.showRewardedAd();
    await tester.pump();
    expect(nativeMethods.indexOf('setServerSideVerificationOptions'), greaterThanOrEqualTo(0));
    expect(
      nativeMethods.indexOf('setServerSideVerificationOptions'),
      lessThan(nativeMethods.indexOf('showAdWithoutView')),
    );
    await adEvent(id, 'onAdDismissedFullScreenContent');
    await shown;
  });

  testWidgets('fullscreen show records spacing even without an impression callback', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final loaded = repository.createRewardedAd();
    await tester.pump();
    final id = loadIds.single;
    await adEvent(id, 'onAdLoaded');
    await loaded;
    final shown = repository.showRewardedAd();
    await tester.pump();
    final before = DateTime.now();
    await adEvent(id, 'onAdShowedFullScreenContent');
    await tester.pump();
    expect((await AdExperimentService.instance.lastFullscreen())!.isBefore(before), isFalse);
    await adEvent(id, 'onAdDismissedFullScreenContent');
    await shown;
  });

  testWidgets('late SDK reward after both old timeouts waits for dismissal and disposes once', (tester) async {
    final loaded = repository.createRewardedAd();
    await tester.pump();
    final id = loadIds.single;
    await adEvent(id, 'onAdLoaded');
    await loaded;
    Result<AdsEntity>? result;
    repository.showRewardedAd().then((value) => result = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 61));
    expect(result, isNull);
    expect(disposedIds, isNot(contains(id)));
    expect((await repository.showRewardedAd()).isFailure, isTrue);
    await adEvent(id, 'onRewardedAdUserEarnedReward', reward: RewardItem(10, 'coins'));
    expect(result, isNull);
    await adEvent(id, 'onAdDismissedFullScreenContent');
    await tester.pump();
    expect(result?.data?.rewardEarned, isTrue);
    expect(disposedIds.where((value) => value == id), hasLength(1));
  });

  testWidgets('UI pending at 60 seconds retains fullscreen ownership and late verified reward', (tester) async {
    final owner = app_state.prismUser;
    final backend = CoinsTestBackend();
    await backend.install();
    CoinsService.instance.resetSession();
    getIt.registerSingleton<AdsRepository>(repository);
    addTearDown(() async {
      app_state.prismUser = owner;
      await getIt.reset();
    });
    bool verified = false;
    int begins = 0;
    backend.onCall = (name, parameters) async {
      if (name == 'beginRewardedSession') {
        begins++;
        return {
          'version': 1,
          'status': 'reserved',
          'sessionId': 'session',
          'userId': app_state.prismUser.id,
          'customData': 'token',
          'adUnitId': 'server-unit',
          'rewardCoins': 7,
          'adsRemaining': 3,
          'showBeforeMs': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        };
      }
      expectSync(name, 'getRewardedSession');
      return {
        'version': 1,
        'sessionId': 'session',
        'status': verified ? 'settled' : 'reserved',
        'rewardCoins': 7,
        'currentBalance': verified ? 107 : 100,
        'adsRemaining': 3,
      };
    };
    final quotes = <int>[];
    final port = AppCoinGatePort(
      () => throw StateError('No UI bloc should be required'),
      confirmRewardQuote: (coins) async {
        quotes.add(coins);
        return true;
      },
    );
    CoinMutationResult? uiResult;
    port.watchVerifiedReward('download').then((value) => uiResult = value);
    await tester.pump();
    final id = loadIds.single;
    await adEvent(id, 'onAdLoaded');
    await tester.pump();
    expect(nativeMethods, contains('showAdWithoutView'));
    expect(quotes, [7]);
    await tester.pump(const Duration(seconds: 61));
    expect(uiResult?.reason, 'reward_pending');
    expect((await port.watchVerifiedReward('another')).reason, 'reward_pending');
    expect(begins, 1);
    expect(disposedIds, isNot(contains(id)));
    await adEvent(id, 'onRewardedAdUserEarnedReward', reward: RewardItem(7, 'coins'));
    await tester.pump();
    expect(CoinsService.instance.balanceNotifier.value, 100);
    verified = true;
    await adEvent(id, 'onAdDismissedFullScreenContent');
    await tester.pump();
    expect(CoinsService.instance.balanceNotifier.value, 107);
    expect(CoinsService.instance.confirmedRewardCoins('session'), 7);
    expect(disposedIds.where((value) => value == id), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('delayed SSV settlement after dismissal completes the verified watch', (tester) async {
    final owner = app_state.prismUser;
    final backend = CoinsTestBackend();
    await backend.install();
    CoinsService.instance.resetSession();
    getIt.registerSingleton<AdsRepository>(repository);
    addTearDown(() async {
      app_state.prismUser = owner;
      await getIt.reset();
    });
    bool verified = false;
    int begins = 0;
    backend.onCall = (name, parameters) async {
      if (name == 'beginRewardedSession') {
        begins++;
        return {
          'version': 1,
          'status': 'reserved',
          'sessionId': 'session',
          'userId': app_state.prismUser.id,
          'customData': 'token',
          'adUnitId': 'server-unit',
          'rewardCoins': 7,
          'adsRemaining': 3,
          'showBeforeMs': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        };
      }
      expectSync(name, 'getRewardedSession');
      return {
        'version': 1,
        'sessionId': 'session',
        'status': verified ? 'settled' : 'reserved',
        'rewardCoins': 7,
        'currentBalance': verified ? 107 : 100,
        'adsRemaining': 3,
      };
    };
    final quotes = <int>[];
    final port = AppCoinGatePort(
      () => throw StateError('No UI bloc should be required'),
      confirmRewardQuote: (coins) async {
        quotes.add(coins);
        return true;
      },
    );
    CoinMutationResult? uiResult;
    port.watchVerifiedReward('download').then((value) => uiResult = value);
    await tester.pump();
    final id = loadIds.single;
    await adEvent(id, 'onAdLoaded');
    await tester.pump();
    expect(nativeMethods, contains('showAdWithoutView'));
    expect(quotes, [7]);
    await adEvent(id, 'onRewardedAdUserEarnedReward', reward: RewardItem(7, 'coins'));
    await adEvent(id, 'onAdDismissedFullScreenContent');
    await tester.pump();
    expect(uiResult, isNull);
    verified = true;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await waitForRealIo(
      tester,
      () => uiResult != null,
      reason: 'delayed signed reward',
      pumpDuration: const Duration(milliseconds: 100),
    );
    expect(begins, 1);
    expect(uiResult?.changed, isTrue);
    expect(uiResult?.delta, 7);
    expect(CoinsService.instance.balanceNotifier.value, 107);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('changed reward quote must be accepted before loading and a declined reservation can be reused', (
    tester,
  ) async {
    final owner = app_state.prismUser;
    final backend = CoinsTestBackend();
    await backend.install();
    CoinsService.instance.resetSession();
    addTearDown(() async {
      app_state.prismUser = owner;
      await getIt.reset();
    });
    int begins = 0;
    backend.onCall = (name, parameters) async {
      if (name == 'getRewardedSession') {
        return {
          'version': 1,
          'sessionId': 'session',
          'status': 'reserved',
          'rewardCoins': 7,
          'currentBalance': 100,
          'adsRemaining': 3,
        };
      }
      begins++;
      return {
        'version': 1,
        'status': 'reserved',
        'sessionId': 'session',
        'userId': app_state.prismUser.id,
        'customData': 'token',
        'adUnitId': 'server-unit',
        'rewardCoins': 7,
        'adsRemaining': 3,
        'showBeforeMs': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
      };
    };
    final quotes = <int>[];
    final port = AppCoinGatePort(
      () => throw StateError('No UI bloc should be required'),
      confirmRewardQuote: (coins) async {
        quotes.add(coins);
        return false;
      },
    );
    expect((await port.watchVerifiedReward('download')).reason, 'reward_quote_cancelled');
    expect((await port.watchVerifiedReward('download')).reason, 'reward_quote_cancelled');
    expect(begins, 1);
    expect(quotes, [7, 7]);
    expect(loadIds, isEmpty);
    expect(nativeMethods, isNot(contains('showAdWithoutView')));
    await getIt<SettingsLocalDataSource>().delete('verifiedRewardSession_v1.${app_state.prismUser.id}');
    await CoinsService.instance.reconcileRewardedSession();
  });

  testWidgets('privacy invalidation during final consent query prevents native show', (tester) async {
    final finalConsent = Completer<bool>();
    int queries = 0;
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => ++queries == 4 ? finalConsent.future : true,
      showPrivacyOptions: () async {},
    );
    repository = AdsRepositoryImpl();
    final loaded = repository.createRewardedAd();
    await tester.pump();
    await adEvent(loadIds.single, 'onAdLoaded');
    await loaded;
    final showing = repository.showRewardedAd();
    await tester.pump();
    expect(queries, 4);
    await AdConsent.instance.showPrivacyOptions();
    finalConsent.complete(true);
    expect((await showing).isFailure, isTrue);
    expect(nativeMethods, isNot(contains('showAdWithoutView')));
  });

  testWidgets('privacy choices invalidate loaded ads and successful consent cache', (tester) async {
    bool allowed = true;
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () async => allowed,
      showPrivacyOptions: () async {
        allowed = false;
      },
    );
    repository = AdsRepositoryImpl();
    final loaded = repository.createRewardedAd();
    await tester.pump();
    final id = loadIds.single;
    await adEvent(id, 'onAdLoaded');
    await loaded;
    await AdConsent.instance.showPrivacyOptions();
    expect(await AdConsent.instance.ensure(), isFalse);
    expect((await repository.showRewardedAd()).isFailure, isTrue);
    expect(disposedIds, contains(id));
    expect(nativeMethods, isNot(contains('showAdWithoutView')));
  });

  testWidgets('a native load that never answers times out and clears its loading state', (tester) async {
    Result<AdsEntity>? result;
    repository.createRewardedAd().then((value) => result = value);
    await tester.pump();
    expect(nativeMethods, contains('loadRewardedAd'));
    await tester.pump(const Duration(seconds: 29));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(result?.failure, isA<NetworkFailure>());
    expect(result?.failure?.message, 'Timed out while loading rewarded ad');
    expect(analytics.events.whereType<AdLoadResultEvent>().single.toWireParameters(), {
      'result': 'failed',
      'reason': 'timeout',
    });
    consent(false);
    final retry = await repository.createRewardedAd();
    expect(retry.data?.loadingAd, false);
    expect(retry.data?.adLoaded, false);
    expect(retry.data?.adFailed, true);
    expect(retry.data?.failureReason, AdFailureReason.consent);
    expect(nativeMethods.where((method) => method == 'loadRewardedAd').length, 1);
  });

  testWidgets('timed-out consent cannot start a native load after a newer refused request', (tester) async {
    final gate = Completer<bool>();
    AdConsent.instance = AdConsent(
      requestInfoUpdate: () async {},
      showFormIfRequired: () async {},
      canRequestAds: () => gate.future,
    );
    Result<AdsEntity>? first;
    repository.createRewardedAd().then((value) => first = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(first?.failure, isA<NetworkFailure>());
    consent(false);
    expect((await repository.createRewardedAd()).data?.failureReason, AdFailureReason.consent);
    gate.complete(true);
    await tester.pump();
    expect(loadIds, isEmpty);
    expect(analytics.events.whereType<AdLoadResultEvent>().length, 2);
  });

  testWidgets('a late loaded ad is disposed and cannot replace a newer loaded ad', (tester) async {
    repository.createRewardedAd();
    await tester.pump();
    final oldId = loadIds.single;
    await tester.pump(const Duration(seconds: 30));
    final second = repository.createRewardedAd();
    await tester.pump();
    final currentId = loadIds.last;
    await adEvent(currentId, 'onAdLoaded');
    expect((await second).data?.adLoaded, isTrue);
    await adEvent(oldId, 'onAdLoaded');
    await tester.pump();
    expect(disposedIds, contains(oldId));
    expect(disposedIds, isNot(contains(currentId)));
    expect(analytics.events.whereType<AdLoadResultEvent>().length, 2);
  });

  testWidgets('a retry scheduled near the deadline cannot load after timeout', (tester) async {
    repository.createRewardedAd();
    await tester.pump();
    await tester.pump(const Duration(seconds: 29));
    await adEvent(loadIds.single, 'onAdFailedToLoad', error: LoadAdError(2, 'test', 'offline', null));
    await tester.pump(const Duration(seconds: 1));
    consent(false);
    await repository.createRewardedAd();
    await tester.pump(const Duration(seconds: 2));
    expect(loadIds.length, 1);
  });

  testWidgets('each logical request gets a fresh retry budget', (tester) async {
    for (int request = 0; request < 2; request++) {
      final pending = repository.createRewardedAd();
      await tester.pump();
      for (int attempt = 0; attempt < 4; attempt++) {
        await adEvent(loadIds.last, 'onAdFailedToLoad', error: LoadAdError(2, 'test', 'offline', null));
        await tester.pump(const Duration(seconds: 2));
      }
      expect((await pending).data?.adFailed, isTrue);
      expect(loadIds.length, (request + 1) * 4);
    }
  });

  testWidgets('only the final SDK failure warns with its domain, code and message', (tester) async {
    final pending = repository.createRewardedAd();
    await tester.pump();
    for (int attempt = 0; attempt < 3; attempt++) {
      await adEvent(
        loadIds.last,
        'onAdFailedToLoad',
        error: LoadAdError(1, 'com.google.admob', 'No ad to show.', null),
      );
      expect(InMemoryLogSink.instance.records.where((record) => record.level == AppLogLevel.warn), isEmpty);
      await tester.pump(const Duration(seconds: 2));
    }
    await adEvent(loadIds.last, 'onAdFailedToLoad', error: LoadAdError(1, 'com.google.admob', 'No ad to show.', null));
    expect((await pending).data?.adFailed, isTrue);
    final warning = InMemoryLogSink.instance.records.where((record) => record.level == AppLogLevel.warn).single;
    expect(warning.tag, 'Ads');
    expect(warning.fields, {'domain': 'com.google.admob', 'code': 1, 'message': 'No ad to show.'});
  });

  testWidgets('consent exceptions terminate the request and allow a later retry', (tester) async {
    AdConsent.instance = _ThrowingConsent();
    expect((await repository.createRewardedAd()).data?.adFailed, isTrue);
    consent(false);
    expect((await repository.createRewardedAd()).data?.failureReason, AdFailureReason.consent);
  });

  testWidgets('native load exceptions clear loading without leaving retry timers', (tester) async {
    throwLoad = true;
    final result = await repository.createRewardedAd();
    expect(result.data?.adFailed, isTrue);
    expect(result.data?.loadingAd, isFalse);
    consent(false);
    expect((await repository.createRewardedAd()).data?.failureReason, AdFailureReason.consent);
  });
}
