import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/creator_tips/views/widgets/tip_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

Map<String, Object?> _paid({int before = 100, int after = 75}) => <String, Object?>{
  'success': true,
  'changed': true,
  'previousBalance': before,
  'currentBalance': after,
  'delta': after - before,
  'reason': 'ok',
};

Map<String, Object?> _refused(String reason) => <String, Object?>{
  'success': false,
  'changed': false,
  'previousBalance': 100,
  'currentBalance': 100,
  'delta': 0,
  'reason': reason,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService service = CoinsService.instance;
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late List<(String, Map<String, dynamic>)> calls;
  late FakeAppAnalytics analytics;

  void reply(Object? Function(String name, Map<String, dynamic> params) answer) {
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      if (name == 'reconcileRankRewards') return <String, Object?>{};
      return answer(name, params);
    };
  }

  // TipSheet uses the smooth_sheets scaffold, which needs a sheet ancestor, so it opens through showTipSheet.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showTipSheet(context, creatorUid: 'maker', creatorName: 'Ava', source: 'wall', wallId: 'neon'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  setUp(() async {
    calls = <(String, Map<String, dynamic>)>[];
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await backend.install();
    service.balanceNotifier.value = 100;
    reply((_, _) => _paid());
    messenger.setMockMethodCallHandler(toastChannel, (MethodCall call) async => true);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await service.refreshStreakStatus();
    EconomyConfig.resetForTest();
    await getIt.reset();
  });

  testWidgets('shows the three amounts, the balance and the cost', (WidgetTester tester) async {
    service.balanceNotifier.value = 100;
    await pumpSheet(tester);

    expect(find.text('10'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Tip Ava'), findsOneWidget);
    expect(find.text('Your balance: 100 coins'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Tip 25 coins')).onPressed, isNotNull);
    expect(analytics.events.map((AnalyticsEvent e) => e.eventName), contains('tip_sheet_opened'));
  });

  testWidgets('picking an amount changes the cost', (WidgetTester tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('50'));
    await tester.pump();

    expect(find.text('Tip 50 coins'), findsOneWidget);
  });

  testWidgets('a short balance disables the tip and links to earn coins', (WidgetTester tester) async {
    service.balanceNotifier.value = 20;
    await pumpSheet(tester);

    expect(find.text('You need 5 more coins.'), findsOneWidget);
    expect(find.text('Earn coins'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Tip 25 coins')).onPressed, isNull);
    await tester.tap(find.text('Tip 25 coins'));
    await tester.pump();
    expect(calls, isEmpty);

    await tester.tap(find.text('10'));
    await tester.pump();
    expect(find.text('You need 5 more coins.'), findsNothing);
  });

  testWidgets('success thanks the user', (WidgetTester tester) async {
    reply(
      (_, _) => <String, Object?>{
        'success': true,
        'changed': true,
        'amount': 25,
        'delta': -25,
        'previousBalance': 100,
        'currentBalance': 75,
        'reason': 'tip_to_maker',
        'transactionId': 'ctx_tip_x',
        'tipId': 'tip_x',
        'insufficientBalance': false,
      },
    );
    await pumpSheet(tester);

    await tester.tap(find.text('Tip 25 coins'));
    await settle(tester);

    expect(find.text('Thanks for your tip'), findsOneWidget);
    expect(find.text('Ava got your 25 coins.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(analytics.events.map((AnalyticsEvent e) => e.eventName), contains('tip_sent'));
  });

  testWidgets('a failure records tip_failed', (WidgetTester tester) async {
    reply((_, _) => _refused('tip_pair_limit'));
    await pumpSheet(tester);

    await tester.tap(find.text('Tip 25 coins'));
    await settle(tester);

    expect(analytics.events.map((AnalyticsEvent e) => e.eventName), contains('tip_failed'));
  });

  group('canTipCreator', () {
    setUp(() {
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = backend.userId
        ..loggedIn = true;
    });

    test('allows a signed-in viewer to tip another creator', () {
      expect(canTipCreator('maker', KnownBlockedCreators(<String>[])), isTrue);
    });

    test('refuses the viewer their own account', () {
      expect(canTipCreator(backend.userId, KnownBlockedCreators(<String>[])), isFalse);
    });

    test('refuses an empty or missing creator', () {
      expect(canTipCreator('', KnownBlockedCreators(<String>[])), isFalse);
      expect(canTipCreator(null, KnownBlockedCreators(<String>[])), isFalse);
    });

    test('refuses a creator the viewer blocked', () {
      expect(canTipCreator('maker', KnownBlockedCreators(<String>['maker'])), isFalse);
    });

    test('refuses while the block list is unknown', () {
      expect(canTipCreator('maker', const UnknownBlockedCreators()), isFalse);
    });

    test('refuses a guest', () {
      app_state.prismUser = app_constants.createGuestPrismUser();
      expect(canTipCreator('maker', KnownBlockedCreators(<String>[])), isFalse);
    });
  });
}
