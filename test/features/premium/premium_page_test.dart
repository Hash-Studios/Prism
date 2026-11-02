import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/premium/views/pages/premium_page.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
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
    PurchasesService.instance.activeTrial.value = null;
    app_state.prismUser = app_constants.createGuestPrismUser();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(purchasesChannel, null);
    await getIt.reset();
  });

  testWidgets('opening Premium waits for the user to view plans', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumPage(),
      ),
    );
    await tester.pump();

    expect(find.text(AppLocalizationsEn().premiumPageTitle), findsOneWidget);
    expect(find.text(AppLocalizationsEn().premiumPageViewPlans), findsOneWidget);
    expect(analytics.events.whereType<PaywallImpressionEvent>(), isEmpty);
  });

  testWidgets('unavailable native plans leave a persistent retry action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumPage(),
      ),
    );
    await tester.tap(find.text(AppLocalizationsEn().premiumPageViewPlans));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().premiumPagePlansUnavailable), findsOneWidget);
    expect(find.text(AppLocalizationsEn().premiumPageTryAgain), findsOneWidget);
    expect(analytics.events.whereType<PaywallImpressionEvent>(), hasLength(1));
    expect(analytics.events.whereType<PaywallResultEvent>(), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a RevenueCat call that never settles stops loading and offers a retry', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      purchasesChannel,
      (_) => Completer<Object?>().future,
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumPage(),
      ),
    );
    await tester.tap(find.text(AppLocalizationsEn().premiumPageViewPlans));
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(find.text(AppLocalizationsEn().premiumPagePlansUnavailable), findsOneWidget);
    expect(find.text(AppLocalizationsEn().premiumPageTryAgain), findsOneWidget);
    expect(analytics.events.whereType<PaywallResultEvent>().single.result, PaywallResultValue.rcError);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('an active trial shows its end date and manage action instead of plans', (tester) async {
    PurchasesService.instance.activeTrial.value = ActiveTrial(
      productId: 'prism_pro_yearly',
      endsAt: DateTime.utc(2026, 11, 8, 10),
      willRenew: true,
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumPage(),
      ),
    );
    await tester.pump();

    expect(find.text('Trial, ends Nov 8, 2026'), findsOneWidget);
    expect(find.text('Manage subscription'), findsOneWidget);
    expect(find.text('View plans'), findsNothing);
    expect(find.text('Auto-renew is off. You will not be charged when the trial ends.'), findsNothing);
  });

  testWidgets('a trial with auto-renew off says it will not charge', (tester) async {
    PurchasesService.instance.activeTrial.value = ActiveTrial(
      productId: 'prism_pro_yearly',
      endsAt: DateTime.utc(2026, 11, 8, 10),
      willRenew: false,
    );
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumPage(),
      ),
    );
    await tester.pump();

    expect(find.text('Trial, ends Nov 8, 2026'), findsOneWidget);
    expect(find.text('Auto-renew is off. You will not be charged when the trial ends.'), findsOneWidget);
  });

  testWidgets('a trial that starts while the page is open replaces View plans', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumPage(),
      ),
    );
    await tester.pump();
    expect(find.text('View plans'), findsOneWidget);

    PurchasesService.instance.activeTrial.value = ActiveTrial(
      productId: 'prism_pro_yearly',
      endsAt: DateTime.utc(2026, 11, 8, 10),
      willRenew: true,
    );
    await tester.pump();

    expect(find.text('View plans'), findsNothing);
    expect(find.text('Trial, ends Nov 8, 2026'), findsOneWidget);
  });
}
