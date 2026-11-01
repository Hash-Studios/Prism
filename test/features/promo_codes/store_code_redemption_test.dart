import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/promo_codes/views/store_code_redemption.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  late Future<void> Function() originalPresentAppStoreSheet;
  late Future<bool> Function(Uri uri) originalOpenExternal;
  late Future<void> Function(String userId) originalEnsureConfigured;
  late List<String> calls;
  late FakeAppAnalytics analytics;
  late int presentCount;
  late List<Uri> opened;
  late List<String> toasts;

  setUp(() {
    originalPresentAppStoreSheet = storeCodeIo.presentAppStoreSheet;
    originalOpenExternal = storeCodeIo.openExternal;
    originalEnsureConfigured = storeCodeIo.ensureConfigured;
    calls = <String>[];
    storeCodeIo.ensureConfigured = (String userId) async => calls.add('configure');
    presentCount = 0;
    opened = <Uri>[];
    toasts = <String>[];
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    storeCodeIo.presentAppStoreSheet = () async {
      presentCount++;
      calls.add('present');
    };
    storeCodeIo.openExternal = (Uri uri) async {
      opened.add(uri);
      return true;
    };
    messenger.setMockMethodCallHandler(toastChannel, (MethodCall call) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
  });

  tearDown(() {
    storeCodeIo.presentAppStoreSheet = originalPresentAppStoreSheet;
    storeCodeIo.openExternal = originalOpenExternal;
    storeCodeIo.ensureConfigured = originalEnsureConfigured;
    messenger.setMockMethodCallHandler(toastChannel, null);
    debugDefaultTargetPlatformOverride = null;
    AnalyticsRuntime.reset();
  });

  Future<void> pumpAndTap(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => openStoreCodeRedemption(context), child: const Text('Open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('on iPhone the App Store code sheet opens and the Play page does not', (tester) async {
    await pumpAndTap(tester);

    expect(calls, <String>['configure', 'present']);
    expect(opened, isEmpty);
    final List<AnalyticsEvent> sent = analytics.events;
    expect(sent.map((AnalyticsEvent e) => e.eventName), <String>['store_code_sheet_opened']);
    expect(sent.single.toWireParameters(), <String, Object?>{'platform': 'ios'});
    expect(toasts, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on Android the Play redeem page opens and the App Store sheet does not', (tester) async {
    await pumpAndTap(tester);

    expect(opened, <Uri>[Uri.parse('https://play.google.com/redeem')]);
    expect(presentCount, 0);
    final List<AnalyticsEvent> sent = analytics.events;
    expect(sent.map((AnalyticsEvent e) => e.eventName), <String>['store_code_sheet_opened']);
    expect(sent.single.toWireParameters(), <String, Object?>{'platform': 'android'});
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on iPhone a RevenueCat setup failure shows the toast and never opens the sheet', (tester) async {
    storeCodeIo.ensureConfigured = (String userId) async => throw StateError('not configured');
    await pumpAndTap(tester);

    expect(presentCount, 0);
    expect(toasts, <String>["Couldn't open the code page. Try again."]);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a Play page that does not open shows the failure toast', (tester) async {
    storeCodeIo.openExternal = (Uri uri) async => false;
    await pumpAndTap(tester);

    expect(toasts, <String>["Couldn't open the code page. Try again."]);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
