import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/repositories/ads_repository_impl.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show AdMessageCodec;

import '../../support/fake_app_analytics.dart';

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

  Future<void> adEvent(int id, String event, {LoadAdError? error}) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      channel,
      codec.encodeMethodCall(
        MethodCall('onAdEvent', <String, Object?>{
          'adId': id,
          'eventName': event,
          if (error != null) 'loadAdError': error,
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
