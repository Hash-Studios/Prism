import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/premium/views/pages/premium_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

void main() {
  late FakeAppAnalytics analytics;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const MethodChannel purchasesChannel = MethodChannel('purchases_flutter');

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    app_state.prismUser = profileUser();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      purchasesChannel,
      (_) async => throw PlatformException(code: 'plans-unavailable'),
    );
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(purchasesChannel, null);
    await getIt.reset();
  });

  testWidgets('opening Premium waits for the user to view plans', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PremiumPage()));
    await tester.pump();

    expect(find.text('Prism Premium'), findsOneWidget);
    expect(find.text('View plans'), findsOneWidget);
    expect(analytics.events.whereType<PaywallImpressionEvent>(), isEmpty);
  });

  testWidgets('unavailable native plans leave a persistent retry action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PremiumPage()));
    await tester.tap(find.text('View plans'));
    await tester.pumpAndSettle();

    expect(find.text(PaywallOrchestrator.plansUnavailableMessage), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(analytics.events.whereType<PaywallImpressionEvent>(), hasLength(1));
    expect(analytics.events.whereType<PaywallResultEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });
}
