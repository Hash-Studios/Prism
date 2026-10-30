import 'package:Prism/features/ads/data/ad_experiment_config.dart';
import 'package:Prism/features/ads/data/ad_experiment_policy.dart';
import 'package:Prism/features/ads/data/ad_experiment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const String enabled = '{"version":"v1","native":true,"banner":true,"interstitial":true}';
  const AdExperimentEligibility eligible = AdExperimentEligibility(
    completedSessions: 2,
    isFree: true,
    consentAllowed: true,
    activePlacement: true,
    onboardingComplete: true,
  );
  final DateTime now = DateTime(2026, 10, 30, 12);

  bool permits({
    AdExperimentFormat format = AdExperimentFormat.native,
    int? bucket = 20,
    AdExperimentEligibility eligibility = eligible,
    int impressions = 0,
    bool shownToday = false,
    bool action = true,
    DateTime? lastFullscreen,
    AdExperimentConfig? config,
  }) => const AdExperimentPolicy().permits(
    config: config ?? AdExperimentConfig.parse(enabled),
    format: format,
    bucket: bucket,
    eligibility: eligibility,
    sessionImpressions: impressions,
    interstitialShownToday: shownToday,
    successfulWallpaperAction: action,
    lastFullscreen: lastFullscreen,
    now: now,
  );

  test('invalid config fails closed', () {
    for (final String value in <String>['', '{}', '[]', '{"version":"v1","native":1}']) {
      expect(permits(config: AdExperimentConfig.parse(value)), isFalse);
    }
  });

  test('holdout and unknown eligibility fail closed', () {
    expect(permits(), isTrue);
    expect(permits(bucket: 19), isFalse);
    expect(permits(bucket: 100), isFalse);
    expect(permits(bucket: null), isFalse);
    expect(
      permits(
        eligibility: const AdExperimentEligibility(
          completedSessions: 2,
          isFree: null,
          consentAllowed: true,
          activePlacement: true,
          onboardingComplete: true,
        ),
      ),
      isFalse,
    );
  });

  test('impression caps and fullscreen spacing', () {
    expect(permits(impressions: 1), isFalse);
    expect(permits(format: AdExperimentFormat.banner, impressions: 1), isFalse);
    expect(permits(format: AdExperimentFormat.interstitial, shownToday: true), isFalse);
    expect(permits(format: AdExperimentFormat.interstitial, action: false), isFalse);
    expect(
      permits(format: AdExperimentFormat.interstitial, lastFullscreen: now.subtract(const Duration(minutes: 29))),
      isFalse,
    );
    expect(
      permits(format: AdExperimentFormat.interstitial, lastFullscreen: now.subtract(const Duration(minutes: 30))),
      isTrue,
    );
    expect(
      permits(format: AdExperimentFormat.interstitial, lastFullscreen: now.add(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('bucket persists and successful action is consumed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AdExperimentService service = AdExperimentService()..applyConfig(enabled);
    final List<int?> buckets = await Future.wait(<Future<int?>>[
      service.bucket(accountId: 'account-a'),
      service.bucket(accountId: 'account-a'),
    ]);
    expect(buckets.first, inInclusiveRange(0, 99));
    expect(buckets.last, buckets.first);
    final AdExperimentService restarted = AdExperimentService()..applyConfig(enabled);
    expect(await restarted.bucket(accountId: 'account-a'), buckets.first);
    final prefs = await SharedPreferences.getInstance();
    final seed = prefs.getString('ad_experiment.install_seed')!;
    expect(await restarted.bucket(accountId: 'account-b'), AdExperimentService.bucketFor('$seed:account-b', 'v1'));
    expect(await restarted.bucket(accountId: ''), isNull);
    expect(service.consumeSuccessfulWallpaperAction(), isFalse);
    service.recordSuccessfulWallpaperAction();
    expect(service.consumeSuccessfulWallpaperAction(), isTrue);
    expect(service.consumeSuccessfulWallpaperAction(), isFalse);
  });

  test('platform ad IDs must be valid and configured for each format', () {
    final config = AdExperimentConfig.parse(
      '{"version":"v1","native":true,"banner":true,"interstitial":true,'
      '"android_native_id":"ca-app-pub-1234567890123456/1234567890",'
      '"ios_native_id":"invalid","android_banner_id":""}',
    );
    expect(
      config.unitId(AdExperimentFormat.native, android: true, isRelease: true),
      'ca-app-pub-1234567890123456/1234567890',
    );
    expect(config.unitId(AdExperimentFormat.native, android: true), 'ca-app-pub-3940256099942544/2247696110');
    expect(config.unitId(AdExperimentFormat.native, android: false), isEmpty);
    expect(config.unitId(AdExperimentFormat.banner, android: true), isEmpty);
    expect(config.unitId(AdExperimentFormat.interstitial, android: true), isEmpty);
  });

  test('interstitial cap uses UTC across local timezone boundaries', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = AdExperimentService();
    await service.recordInterstitialImpression(at: DateTime.parse('2026-10-30T23:55:00Z'));
    expect(await service.interstitialShownToday(at: DateTime.parse('2026-10-31T05:20:00+05:30')), isTrue);
    expect(await service.interstitialShownToday(at: DateTime.parse('2026-10-31T05:31:00+05:30')), isFalse);
  });

  test('completed background session is persisted exactly once across restarts', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ad_experiment.session':
          '{"count":1,"background":${DateTime.now().subtract(const Duration(minutes: 31)).millisecondsSinceEpoch}}',
    });
    final service = AdExperimentService();
    await service.start();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ad_experiment.session'), '{"count":2,"background":null,"native":0,"banner":0}');
    service.dispose();
    final restarted = AdExperimentService();
    await restarted.start();
    expect(prefs.getString('ad_experiment.session'), '{"count":2,"background":null,"native":0,"banner":0}');
    restarted.dispose();
  });

  test('inline caps survive process restart within a session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = AdExperimentService();
    await first.start();
    await first.recordInlineImpression(AdExperimentFormat.native);
    await first.recordInlineImpression(AdExperimentFormat.banner);
    first.dispose();
    final restarted = AdExperimentService();
    await restarted.start();
    expect(restarted.claimInline(AdExperimentFormat.native), isFalse);
    expect(restarted.claimInline(AdExperimentFormat.banner), isFalse);
    restarted.dispose();
  });

  test('only one inline placement can own an unfilled session slot', () {
    final service = AdExperimentService();
    expect(service.claimInline(AdExperimentFormat.native), isTrue);
    expect(service.claimInline(AdExperimentFormat.native), isFalse);
    service.releaseInline(AdExperimentFormat.native);
    expect(service.claimInline(AdExperimentFormat.native), isTrue);
    service.recordInlineImpression(AdExperimentFormat.native);
    service.releaseInline(AdExperimentFormat.native);
    expect(service.claimInline(AdExperimentFormat.native), isFalse);
    expect(service.claimInline(AdExperimentFormat.banner), isTrue);
  });
}
