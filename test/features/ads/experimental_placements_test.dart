import 'dart:async';

import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/data/ad_experiment_service.dart';
import 'package:Prism/features/ads/views/widgets/experimental_inline_ad.dart';
import 'package:Prism/features/ads/views/widgets/experimental_interstitial_return.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _EligibleService extends AdExperimentService {
  Future<void> readiness = Future<void>.value();
  @override
  Future<void> initializeAds() => readiness;

  bool allowed = true;
  Completer<bool>? eligibility;
  _EligibleService() {
    applyConfig(
      '{"version":"v1","native":true,"banner":true,"interstitial":true,'
      '"android_banner_id":"ca-app-pub-1234567890123456/1234567890",'
      '"android_interstitial_id":"ca-app-pub-1234567890123456/1234567891"}',
    );
  }

  @override
  Future<bool> permits(AdExperimentFormat format, {required bool active, bool action = false}) async =>
      eligibility?.future ?? allowed;

  @override
  Future<int?> bucket({String? accountId}) async => 42;
}

void main() {
  for (final allowed in [true, false]) {
    testWidgets('inline rechecks privacy result $allowed after the form closes', (tester) async {
      final original = AdConsent.instance;
      final form = Completer<void>();
      final service = _EligibleService();
      AdConsent.instance = AdConsent(showPrivacyOptions: () => form.future);
      addTearDown(() => AdConsent.instance = original);
      int requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExperimentalInlineAd(
              format: AdExperimentFormat.banner,
              active: true,
              android: true,
              service: service,
              loadAd: (_) async {
                requests++;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(requests, 1);
      final privacy = AdConsent.instance.showPrivacyOptions();
      await tester.pump();
      expect(requests, 1);
      service.allowed = allowed;
      form.complete();
      await privacy;
      await tester.pump();
      expect(requests, allowed ? 2 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('covered detail cannot request an interstitial after eligibility resolves', (tester) async {
    final service = _EligibleService()..eligibility = Completer<bool>();
    final navigation = GlobalKey<NavigatorState>();
    int requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigation,
        home: Builder(
          builder: (context) => ExperimentalInterstitialReturn(
            grid: context,
            service: service,
            android: true,
            loadAd: (_, _) async {
              requests++;
            },
            child: const Scaffold(body: Text('Detail')),
          ),
        ),
      ),
    );
    await tester.pump();
    unawaited(
      navigation.currentState!.push<void>(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Cover')))),
    );
    await tester.pumpAndSettle();
    service.eligibility!.complete(true);
    await tester.pump();
    expect(requests, 0);
  });

  testWidgets('deep ad slot does not request until scrolling approaches it', (tester) async {
    final service = _EligibleService();
    int requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 3000)),
              DeferredAdSliver(
                child: ExperimentalInlineAd(
                  format: AdExperimentFormat.banner,
                  active: true,
                  android: true,
                  service: service,
                  loadAd: (_) async {
                    requests++;
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 1000)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(requests, 0);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2800));
    await tester.pump();
    expect(requests, 1);
  });

  testWidgets('placement waits for SDK initialization before requesting', (tester) async {
    final ready = Completer<void>();
    final service = _EligibleService()..readiness = ready.future;
    int requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExperimentalInlineAd(
            format: AdExperimentFormat.banner,
            active: true,
            android: true,
            service: service,
            loadAd: (_) async {
              requests++;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(requests, 0);
    ready.complete();
    await tester.pump();
    expect(requests, 1);
  });

  testWidgets('SDK no-fill collapses an active banner', (tester) async {
    final service = _EligibleService();
    BannerAd? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ExperimentalInlineAd(
                format: AdExperimentFormat.banner,
                active: true,
                android: true,
                service: service,
                loadAd: (ad) async => requested = ad as BannerAd,
              ),
              const Text('Earn'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(requested, isNotNull);
    requested!.listener.onAdFailedToLoad!(requested!, LoadAdError(3, 'test', 'no fill', null));
    await tester.pump();
    expect(tester.getSize(find.byType(ExperimentalInlineAd)).height, 0);
    expect(find.byType(AdWidget), findsNothing);
  });

  testWidgets('hidden Rewards tab neither requests nor displays an ad', (tester) async {
    final service = _EligibleService();
    var requests = 0;
    BannerAd? requested;
    Widget screen(bool visible) => MaterialApp(
      home: Scaffold(
        body: TickerMode(
          enabled: visible,
          child: ExperimentalInlineAd(
            format: AdExperimentFormat.banner,
            active: true,
            android: true,
            service: service,
            loadAd: (ad) async {
              requests++;
              requested = ad as BannerAd;
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    await tester.pump();
    expect(requests, 0);
    expect(find.byType(AdWidget), findsNothing);
    await tester.pumpWidget(screen(true));
    await tester.pump();
    expect(requests, 1);
    await tester.pumpWidget(screen(false));
    await tester.pump();
    requested!.listener.onAdLoaded!(requested!);
    await tester.pump();
    expect(find.byType(AdWidget), findsNothing);
  });

  testWidgets('privacy invalidation discards a late SDK load callback', (tester) async {
    final service = _EligibleService();
    BannerAd? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExperimentalInlineAd(
            format: AdExperimentFormat.banner,
            active: true,
            android: true,
            service: service,
            loadAd: (ad) async => requested = ad as BannerAd,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(requested, isNotNull);
    for (final listener in List<VoidCallback>.of(AdConsent.instance.invalidationListeners)) {
      listener();
    }
    requested!.listener.onAdLoaded!(requested!);
    await tester.pump();
    expect(find.byType(AdWidget), findsNothing);
    expect(service.bannerImpressions, 0);
  });
  testWidgets('inactive inline placement has no height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ExperimentalInlineAd(format: AdExperimentFormat.banner, active: false),
              Text('Earn'),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ExperimentalInlineAd)).height, 0);
    expect(find.text('Earn'), findsOneWidget);
  });

  testWidgets('return without a loaded interstitial never blocks navigation', (tester) async {
    final service = AdExperimentService.instance;
    service.applyConfig('{}');
    service.consumeSuccessfulWallpaperAction();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (grid) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(grid).push<void>(
                MaterialPageRoute<void>(
                  builder: (detailContext) => ExperimentalInterstitialReturn(
                    grid: grid,
                    child: Scaffold(
                      body: TextButton(
                        onPressed: () {
                          service.recordSuccessfulWallpaperAction();
                          Navigator.of(detailContext).pop();
                        },
                        child: const Text('Return'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Browse'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return'));
    await tester.pumpAndSettle();
    expect(find.text('Browse'), findsOneWidget);
    expect(service.consumeSuccessfulWallpaperAction(), isFalse);
  });
}
