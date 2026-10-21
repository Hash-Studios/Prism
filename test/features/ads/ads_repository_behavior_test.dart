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

import '../../support/fake_app_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = 'plugins.flutter.io/google_mobile_ads';
  late AdConsent originalConsent;
  late FakeAppAnalytics analytics;
  late AdsRepositoryImpl repository;
  late List<String> nativeMethods;

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
    messenger.setMockMessageHandler(channel, (ByteData? message) async {
      // Only read the standard method name, leaving the SDK's ad objects opaque.
      final method = const StandardMessageCodec().readValue(ReadBuffer(message!))! as String;
      nativeMethods.add(method);
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
}
