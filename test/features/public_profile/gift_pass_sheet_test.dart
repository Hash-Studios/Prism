import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/views/widgets/gift_pass_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

void main() {
  final backend = CoinsTestBackend();
  late FakeAppAnalytics analytics;
  late List<String> messages;
  setUp(() async {
    await backend.install();
    CoinsService.instance.balanceNotifier.value = 100;
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    messages = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        if (call.method == 'showToast') messages.add((call.arguments as Map)['msg'] as String);
        return true;
      },
    );
  });
  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Gift to Ana'),
              onPressed: () => showPrismSheet<void>(
                context,
                builder: (_) => const GiftPassSheet(recipientUid: 'ana', recipientName: 'Ana'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Gift to Ana'));
    await tester.pumpAndSettle();
  }

  testWidgets('insufficient balance disables sending, then a balance update enables it', (tester) async {
    CoinsService.instance.balanceNotifier.value = CoinPolicy.giftPremiumPass - 1;
    await open(tester);
    PrismButton send() => tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Send gift'));
    expect(send().onPressed, isNull);
    expect(find.text('Earn coins'), findsOneWidget);
    CoinsService.instance.balanceNotifier.value = CoinPolicy.giftPremiumPass;
    await tester.pump();
    expect(send().onPressed, isNotNull);
    expect(find.text('Earn coins'), findsNothing);
  });

  for (final refusal in <String, String>{
    'gift_daily_limit': 'Gift limit reached for now. Try again tomorrow.',
    'gift_recipient_premium': 'Ana already has Pro.',
    'gift_sender_too_new': 'Gifts open when your account is 7 days old.',
    'gift_blocked': "You can't send a gift to this account.",
  }.entries) {
    testWidgets('server refusal ${refusal.key} closes the sheet and reports the reason', (tester) async {
      backend.onCall = (_, _) async => <String, Object?>{
        'success': false,
        'changed': false,
        'currentBalance': 100,
        'reason': refusal.key,
      };
      await open(tester);
      await tester.tap(find.text('Send gift'));
      await tester.pumpAndSettle();
      expect(find.byType(GiftPassSheet), findsNothing);
      expect(messages.single, refusal.value);
      expect(analytics.events.where((event) => event.eventName == 'gift_sent'), isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('a pending gift prevents dismissal and success records the recipient', (tester) async {
    final response = Completer<Map<String, Object?>>();
    backend.callStarted = Completer<void>();
    final calls = <Map<String, dynamic>>[];
    backend.onCall = (_, params) {
      calls.add(params);
      return response.future;
    };
    await open(tester);
    await tester.tap(find.text('Send gift'));
    await tester.pump();
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).loading, isTrue);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    await tester.runAsync(() => backend.callStarted!.future);
    response.complete(<String, Object?>{
      'success': true,
      'changed': true,
      'previousBalance': 100,
      'currentBalance': 50,
      'delta': -50,
      'reason': 'ok',
    });
    await tester.pumpAndSettle();
    expect(calls.single['recipientUid'], 'ana');
    expect(find.byType(GiftPassSheet), findsNothing);
    expect(
      analytics.events.where((event) => event.eventName == 'gift_sent').single.toWireParameters(),
      containsPair('recipient_uid', 'ana'),
    );
    expect(messages.single, contains('Ana'));
    await tester.pump(const Duration(seconds: 1));
  });
}
