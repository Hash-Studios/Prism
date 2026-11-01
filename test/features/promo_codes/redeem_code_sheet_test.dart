import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/promo_codes/data/promo_code_repository.dart';
import 'package:Prism/features/promo_codes/domain/entities/promo_code.dart';
import 'package:Prism/features/promo_codes/views/redeem_code_sheet.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

/// Records every callable and answers with [reply], or throws [error] when it is set.
class _FakeCallable {
  final List<(String, Map<String, Object?>)> calls = <(String, Map<String, Object?>)>[];
  Object? reply;
  Object? error;
  void Function()? onReply;

  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls.add((name, data));
    if (error != null) throw error!;
    onReply?.call();
    return reply;
  }

  List<Map<String, Object?>> get redeemData => <Map<String, Object?>>[
    for (final (String name, Map<String, Object?> data) in calls)
      if (name == 'redeemCode') data,
  ];
}

Map<String, Object?> _coinsReply(int balance) => <String, Object?>{
  'ok': true,
  'reward': <String, Object?>{'type': 'coins', 'coins': 100},
  'coinBalance': balance,
  'replayed': false,
};

Map<String, Object?> _failReply(String reason) => <String, Object?>{'ok': false, 'reason': reason};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCallable fake;
  late List<RedeemSucceeded> redeemed;
  late FakeAppAnalytics analytics;

  setUp(() {
    fake = _FakeCallable();
    redeemed = <RedeemSucceeded>[];
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AnalyticsRuntime.reset();
  });

  /// Opens the sheet from a button, the way the app does. [textScale] wraps the app in a MediaQuery override.
  Future<void> openSheet(WidgetTester tester, {String? initialCode, double textScale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPrismSheet<void>(
                  context,
                  builder: (_) => RedeemCodeBody(
                    repository: PromoCodeRepository(call: fake.call),
                    onRedeemed: redeemed.add,
                    initialCode: initialCode,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.pump();
  }

  Future<void> tapRedeem(WidgetTester tester) async {
    await tester.tap(find.text('Redeem'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  String fieldText(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText).first).controller.text;

  testWidgets('editing state shows the title, the code field, the paste button and Redeem', (tester) async {
    await openSheet(tester);

    expect(find.text('Redeem a code'), findsOneWidget);
    expect(find.text('Enter a code from a Prism post or giveaway.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Paste code'), findsOneWidget);
    expect(find.text('Redeem'), findsOneWidget);
  });

  testWidgets('a coin code sends a normalized request and shows the coin success', (tester) async {
    fake.reply = _coinsReply(150);
    await openSheet(tester);

    await enterCode(tester, 'abcd efgh 23');
    await tapRedeem(tester);

    expect(fake.calls.map((c) => c.$1), <String>['redeemCode']);
    final Map<String, Object?> data = fake.calls.single.$2;
    expect(data['code'], 'ABCDEFGH23');
    expect(data['requestId'], isA<String>());
    expect((data['requestId']! as String).isNotEmpty, isTrue);
    expect(data['platform'], 'android');
    expect(find.text('You got 100 coins'), findsOneWidget);
    expect(find.text("They're in your balance now."), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(redeemed, hasLength(1));
    expect(redeemed.single.coinBalance, 150);
  });

  testWidgets('a response for an account that signed out is not applied to the next account', (tester) async {
    final previousUser = app_state.prismUser;
    app_state.prismUser = profileUser(id: 'account-a');
    fake.reply = _coinsReply(150);
    fake.onReply = () => app_state.prismUser = profileUser(id: 'account-b');
    addTearDown(() => app_state.prismUser = previousUser);
    await openSheet(tester);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);

    expect(redeemed, isEmpty);
    expect(find.text('Sign in to redeem a code.'), findsOneWidget);

    fake.onReply = null;
    await tapRedeem(tester);

    expect(redeemed, hasLength(1));
    expect(fake.redeemData, hasLength(2));
    expect(fake.redeemData.last['requestId'], isNot(fake.redeemData.first['requestId']));
  });

  testWidgets('a replayed grant is identified so old totals are not applied as current state', (tester) async {
    fake.reply = <String, Object?>{..._coinsReply(150), 'replayed': true};
    await openSheet(tester);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);

    expect(redeemed, hasLength(1));
    expect(redeemed.single.replayed, isTrue);
  });

  testWidgets('a Pro code shows the Pro success headline', (tester) async {
    fake.reply = <String, Object?>{
      'ok': true,
      'reward': <String, Object?>{'type': 'premiumDays', 'days': 3},
      'premiumUntil': DateTime(2026, 11, 4).millisecondsSinceEpoch,
      'replayed': false,
    };
    await openSheet(tester);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);

    expect(find.text('You got 3 days of Pro'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(redeemed, hasLength(1));
    expect(redeemed.single.reward, isA<PremiumDaysReward>());
  });

  final Map<String, String> errors = <String, String>{
    'expired': 'This code has expired.',
    'already_redeemed': 'You already used this code.',
    'not_found': "We can't find that code. Check it and try again.",
    'limit_reached': 'This code has no uses left.',
    'account_too_new': 'Your account is too new for this code.',
    'new_users_only': 'This code is for new accounts only.',
    'premium_not_on_ios': "Pro codes don't work on iPhone or iPad. Use an App Store code instead.",
    'already_premium': "You already have Pro, so this code isn't needed.",
    'rate_limited': 'Too many tries. Wait an hour, then try again.',
    'busy': 'Lots of people are redeeming right now. Try again in a moment.',
    'disabled': 'This code is turned off.',
  };

  for (final MapEntry<String, String> entry in errors.entries) {
    testWidgets('the ${entry.key} reply shows its message under the field and no success', (tester) async {
      fake.reply = _failReply(entry.key);
      await openSheet(tester);

      await enterCode(tester, 'ABCDEFGH23');
      await tapRedeem(tester);

      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.textContaining('You got'), findsNothing);
      expect(redeemed, isEmpty);
    });
  }

  testWidgets('a long error wraps under the field instead of being cut off', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake.reply = _failReply('premium_not_on_ios');
    await openSheet(tester, textScale: 1.5);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);

    final RenderParagraph error = tester.renderObject<RenderParagraph>(
      find.text("Pro codes don't work on iPhone or iPad. Use an App Store code instead."),
    );
    expect(error.didExceedMaxLines, isFalse);
  });

  testWidgets('a code with the wrong shape is refused before any call', (tester) async {
    await openSheet(tester);

    await enterCode(tester, 'ABC');
    await tapRedeem(tester);

    expect(find.text("That isn't a Prism code. Codes have 10 or more letters and numbers."), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a network failure shows the connection message and a retry reuses the request id', (tester) async {
    fake.error = Exception('offline');
    await openSheet(tester);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);
    expect(find.text("Can't reach Prism. Check your connection and try again."), findsOneWidget);

    fake.error = null;
    fake.reply = _coinsReply(10);
    await tapRedeem(tester);

    final List<Map<String, Object?>> data = fake.redeemData;
    expect(data, hasLength(2));
    expect(data[1]['requestId'], data[0]['requestId']);
  });

  testWidgets('after an expired reply the next attempt uses a new request id', (tester) async {
    fake.reply = _failReply('expired');
    await openSheet(tester);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);
    expect(find.text('This code has expired.'), findsOneWidget);

    fake.reply = _failReply('expired');
    await tapRedeem(tester);

    final List<Map<String, Object?>> data = fake.redeemData;
    expect(data, hasLength(2));
    expect(data[1]['requestId'], isNot(data[0]['requestId']));
  });

  testWidgets('a deep link prefills the code and never redeems on its own', (tester) async {
    await openSheet(tester, initialCode: 'abcdefgh23');
    await tester.pumpAndSettle();

    expect(fieldText(tester), 'ABCDEFGH23');
    expect(fake.calls, isEmpty);
  });

  testWidgets('paste fills the field with the clipboard text, normalized', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.getData') return <String, Object?>{'text': ' 7kq2-mpxr-4d '};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await openSheet(tester);

    await tester.tap(find.byTooltip('Paste code'));
    await tester.pump();
    await tester.pump();

    expect(fieldText(tester), '7KQ2-MPXR-4D');
  });

  testWidgets('the code never reaches analytics, and the outcomes are recorded', (tester) async {
    fake.reply = _failReply('expired');
    await openSheet(tester);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);

    fake.reply = _coinsReply(150);
    await tapRedeem(tester);

    expect(
      analytics.events.map((AnalyticsEvent e) => e.eventName),
      containsAll(<String>['redeem_succeeded', 'redeem_failed']),
    );
    for (final AnalyticsEvent event in analytics.events) {
      for (final Object? value in event.toWireParameters().values) {
        expect(value.toString(), isNot(contains('ABCDEFGH23')), reason: event.eventName);
      }
    }
  });

  testWidgets('on iPhone the message asks for a coin code and the call says ios', (tester) async {
    fake.reply = _coinsReply(150);
    await openSheet(tester);

    expect(find.text('Enter a coin code from a Prism post or giveaway.'), findsOneWidget);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);

    expect(fake.redeemData.single['platform'], 'ios');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('large text overflows neither the editing state nor the success state', (tester) async {
    fake.reply = _coinsReply(150);
    await openSheet(tester, textScale: 2);

    expect(tester.takeException(), isNull);

    await enterCode(tester, 'ABCDEFGH23');
    await tapRedeem(tester);

    expect(find.text('You got 100 coins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
