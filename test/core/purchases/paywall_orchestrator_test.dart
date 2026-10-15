import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final orchestrator = PaywallOrchestrator.instance;
  late FakeAppAnalytics fakeAnalytics;
  late SettingsLocalDataSource settings;
  late List<String> toasts;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    fakeAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = fakeAnalytics;
    app_state.prismUser = profileUser();
    toasts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map)['msg'] as String);
      return true;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
  });

  group('present', () {
    test('tells the user when no paywall can be shown', () async {
      final result = await orchestrator.present(placement: PaywallPlacement.lowBalance, source: 'test');

      expect(const <PaywallResultValue>{
        PaywallResultValue.notPresented,
        PaywallResultValue.noOffering,
        PaywallResultValue.rcError,
      }, contains(result));
      expect(toasts, <String>[PaywallOrchestrator.plansUnavailableMessage]);
      expect(
        PaywallOrchestrator.plansUnavailableMessage,
        'Plans are not available right now. Check your connection and try again.',
      );
    });
  });

  group('rewarded ad upsell', () {
    const promptedAtKey = 'paywall_ad_watch_prompted_at';

    Future<void> watch(int times) async {
      for (int i = 0; i < times; i++) {
        await orchestrator.recordRewardedAdWatchAndMaybeUpsell(source: 'test');
      }
    }

    int impressions() => fakeAnalytics.events.whereType<PaywallImpressionEvent>().length;

    test('the third watched ad opens the paywall once', () async {
      await watch(2);
      expect(impressions(), 0);

      await watch(1);
      expect(impressions(), 1);
      expect(settings.get<int>(promptedAtKey, defaultValue: 0), greaterThan(0));

      await watch(2);
      expect(impressions(), 1);
    });

    test('the paywall opens again after 24 hours', () async {
      await watch(3);
      final yesterday = DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      await settings.set(promptedAtKey, yesterday);

      await watch(1);

      expect(impressions(), 2);
      expect(settings.get<int>(promptedAtKey, defaultValue: 0), greaterThan(yesterday));
    });

    test('a Pro user resets the counter and is never asked', () async {
      await watch(3);
      app_state.prismUser = profileUser(premium: true);

      await watch(1);

      expect(impressions(), 1);
      expect(settings.get<int>(promptedAtKey, defaultValue: 0), 0);
    });
  });
}
