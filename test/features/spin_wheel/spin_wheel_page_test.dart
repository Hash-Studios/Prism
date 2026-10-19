import 'dart:async';

import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/spin_wheel/views/pages/spin_wheel_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../qa_render/qa_harness.dart' show loadFonts;

const SpinWheelStatus _free = SpinWheelStatus(freeSpinAvailable: true, paidSpinsLeft: 5, price: 10);
const SpinWheelStatus _paid = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 4, price: 10);
const SpinWheelStatus _capped = SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 0, price: 10);

const int _startBalance = 340;

/// A landed spin. [balance] defaults to the start balance less the price plus the coins won.
SpinWon _won(
  int segment, {
  int coins = 0,
  int xp = 0,
  String? itemId,
  int cost = 10,
  int? balance,
  SpinWheelStatus status = _paid,
  List<WheelSegment> segments = defaultWheel,
}) => SpinWon(
  win: WheelWin(segment: segment, coins: coins, xp: xp, itemId: itemId),
  cost: cost,
  balance: balance ?? _startBalance - cost + coins,
  segments: segments,
  status: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const MethodChannel hapticChannel = MethodChannel('prism/haptics');
  final List<String> toasts = <String>[];
  final List<String> haptics = <String>[];
  final List<Duration> selectionTimes = <Duration>[];

  late ValueNotifier<SpinWheelStatus> status;
  late ValueNotifier<int> balance;
  late List<int> maxCosts;
  late List<Completer<SpinWheelResult>> replies;

  setUpAll(loadFonts);

  setUp(() {
    toasts.clear();
    haptics.clear();
    selectionTimes.clear();
    status = ValueNotifier<SpinWheelStatus>(_free);
    balance = ValueNotifier<int>(_startBalance);
    maxCosts = <int>[];
    replies = <Completer<SpinWheelResult>>[];
    PrismHaptics.enabled = true;
    final TestDefaultBinaryMessengerBinding binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (MethodCall call) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, (MethodCall call) async {
      if (call.method == 'play') {
        haptics.add(call.arguments as String);
        if (call.arguments == 'selection') selectionTimes.add(binding.currentSystemFrameTimeStamp);
      }
      return null;
    });
  });

  tearDown(() {
    final TestDefaultBinaryMessengerBinding binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, null);
    status.dispose();
    balance.dispose();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<SpinWheelResult> spin({required int maxCost}) {
    maxCosts.add(maxCost);
    final Completer<SpinWheelResult> reply = Completer<SpinWheelResult>();
    replies.add(reply);
    return reply.future;
  }

  Future<void> pumpPage(WidgetTester tester, {bool reduceMotion = false, bool pro = false}) async {
    app_state.prismUser.premium = pro;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: kLightTheme,
          home: SpinWheelPage(spin: spin, status: status, balance: balance),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Pumps 50 ms frames until [finder] matches. The bulbs loop for ever, so `pumpAndSettle` would time out.
  Future<void> pumpUntil(WidgetTester tester, Finder finder, {int maxFrames = 400}) async {
    for (int i = 0; i < maxFrames && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    for (Duration t = Duration.zero; t < total; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapSpin(WidgetTester tester) async {
    await tester.tap(find.text('SPIN'));
    await tester.pump();
  }

  group('the button', () {
    testWidgets('a free spin reads SPIN and Free spin', (tester) async {
      await pumpPage(tester, pro: true);

      expect(find.text('SPIN'), findsOneWidget);
      expect(find.text('Free spin'), findsOneWidget);
      expect(find.bySemanticsLabel('Spin, free spin'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economyFreeSpinReady(5)), findsOneWidget);
      expect(find.text('Pro members get a free spin every day'), findsNothing);
    });

    testWidgets('a paid spin reads SPIN and its price', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      expect(find.text('SPIN'), findsOneWidget);
      expect(find.text('Free spin'), findsNothing);
      expect(find.descendant(of: find.bySemanticsLabel('Spin, 10 coins'), matching: find.text('10')), findsWidgets);
      expect(find.text('4 spins left today.'), findsOneWidget);
      expect(find.text('Pro members get a free spin every day'), findsOneWidget);
    });

    testWidgets('a short balance reads Get coins and the pill warns', (tester) async {
      status.value = _paid;
      balance.value = 4;
      await pumpPage(tester);

      expect(find.text('Get coins'), findsOneWidget);
      expect(find.text('SPIN'), findsNothing);
      expect(find.text('A spin costs 10 coins'), findsOneWidget);
    });

    testWidgets('Get coins opens a sheet that offers a video', (tester) async {
      status.value = _paid;
      balance.value = 4;
      await pumpPage(tester);

      await tester.tap(find.text('Get coins'));
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('Not enough coins'), findsOneWidget);
      expect(find.text('A spin costs 10 coins. You have 4. Watch a video to earn more.'), findsOneWidget);
      expect(find.textContaining('Watch a video (+'), findsOneWidget);
      expect(maxCosts, isEmpty, reason: 'No spin is sent while the balance is short');

      await tester.tap(find.text('Not now'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('Not enough coins'), findsNothing);
    });

    testWidgets('at the cap the button is disabled and reads Back tomorrow', (tester) async {
      status.value = _capped;
      await pumpPage(tester, pro: true);

      expect(find.text('Back tomorrow'), findsOneWidget);
      expect(find.text('SPIN'), findsNothing);
      expect(find.text('No spins left today.'), findsOneWidget);
      await tester.tap(find.text('Back tomorrow'));
      await tester.pump();
      expect(maxCosts, isEmpty);
    });
  });

  group('a spin', () {
    testWidgets('sends the price it shows, then shows a coin win only after the wheel lands', (tester) async {
      status.value = _paid;
      await pumpPage(tester);
      expect(find.text('340'), findsOneWidget);

      await tapSpin(tester);
      expect(maxCosts, <int>[10]);
      // The cost leaves the displayed balance when the spin starts.
      expect(find.text('330'), findsOneWidget);
      expect(find.text('340'), findsNothing);

      replies.single.complete(_won(4, coins: 20));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+20'), findsNothing);
      expect(find.text('Spin again'), findsNothing);
      expect(find.text('330'), findsOneWidget);
      expect(find.text('350'), findsNothing);

      await pumpUntil(tester, find.text('Spin again'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Added to your balance'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(haptics, contains('success'));
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('shows the balance the server reports after the spin, whatever the page expected', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(_won(4, coins: 20, balance: 777));
      await pumpUntil(tester, find.text('Spin again'));
      await pumpFor(tester, const Duration(seconds: 2));

      expect(find.text('777'), findsOneWidget);
      expect(find.text('350'), findsNothing);
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('back does not close the machine while the wheel turns', (tester) async {
      status.value = _paid;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: kLightTheme,
          home: const SizedBox(),
        ),
      );
      final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SpinWheelPage(spin: spin, status: status, balance: balance),
          ),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 500));

      await tapSpin(tester);
      expect(await navigator.maybePop(), isTrue);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.byType(SpinWheelPage), findsOneWidget);

      replies.single.complete(_won(4, coins: 20));
      await pumpUntil(tester, find.text('Spin again'));
      expect(await navigator.maybePop(), isTrue);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(SpinWheelPage), findsNothing);
    });

    testWidgets('a free spin sends a max cost of 0 and does not touch the balance', (tester) async {
      await pumpPage(tester, pro: true);

      await tapSpin(tester);
      expect(maxCosts, <int>[0]);
      expect(find.text('340'), findsOneWidget);
      replies.single.complete(_won(2, coins: 5, cost: 0));
      await pumpUntil(tester, find.text('Spin again'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('345'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('the jackpot is called out', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(_won(3, coins: 100));
      await pumpUntil(tester, find.text('Jackpot. Added to your balance'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+100'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('a historical XP win shows +N XP', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(
        _won(
          5,
          xp: 50,
          segments: <WheelSegment>[
            ...defaultWheel.take(5),
            const WheelSegment(XpPrize(50), weight: 12),
            ...defaultWheel.skip(6),
          ],
        ),
      );
      await pumpUntil(tester, find.text('Added to your XP'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('XP'), findsWidgets);
      // An XP prize pays no coins: the balance only loses the price.
      expect(find.text('330'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('a cosmetic win names the item and its kind from the shop', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(_won(7, itemId: 'frame_ring'));
      await pumpUntil(tester, find.text('New frame: Ring'));
      expect(find.text('Added to your collection'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('a cosmetic that pays coins says every one is owned', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(_won(7, coins: 50));
      await pumpUntil(tester, find.text('You own every cosmetic, so it pays coins'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('380'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('the wheel lands on the table the server spun, even if it has other slices', (tester) async {
      status.value = _paid;
      await pumpPage(tester);
      const List<WheelSegment> table = <WheelSegment>[
        WheelSegment(CoinsPrize(7), weight: 1),
        WheelSegment(XpPrize(15), weight: 1),
        WheelSegment(CoinsPrize(9), weight: 2),
      ];

      await tapSpin(tester);
      replies.single.complete(_won(2, coins: 9, segments: table));
      await pumpUntil(tester, find.text('Spin again'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+9'), findsOneWidget);

      await tester.tap(find.text('See the odds'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('7 coins'), findsOneWidget);
      expect(find.text('15 XP'), findsOneWidget);
      expect(find.text('9 coins'), findsOneWidget);
      expect(find.text('25%'), findsNWidgets(2));
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('18 coins'), findsNothing);
      await tester.tap(find.text('Close'));
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('Spin again sends the next spin with the new price', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(_won(2, coins: 5));
      await pumpUntil(tester, find.text('Spin again'));
      await pumpFor(tester, const Duration(seconds: 2));

      await tester.tap(find.text('Spin again'));
      await tester.pump();
      expect(maxCosts, <int>[10, 10]);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('Spin again'), findsNothing);
      replies.last.complete(_won(0, coins: 10));
      await pumpUntil(tester, find.text('Spin again'));
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('at the cap after a spin, Spin again becomes Back tomorrow and is disabled', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(_won(2, coins: 5, status: _capped));
      await pumpUntil(tester, find.text('Back tomorrow'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('Spin again'), findsNothing);
      await tester.tap(find.text('Back tomorrow'));
      await tester.pump();
      expect(maxCosts, <int>[10]);
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('one press sends one spin, however many times it is tapped while turning', (tester) async {
      await pumpPage(tester, pro: true);

      await tapSpin(tester);
      await tester.tap(find.text('SPIN'), warnIfMissed: false);
      await tester.pump();
      expect(maxCosts, <int>[0]);
      replies.single.complete(const SpinFailed('timeout'));
      await pumpFor(tester, const Duration(seconds: 2));
    });
  });

  group('refusals and failures', () {
    testWidgets('a daily limit stops the wheel and the button reads Back tomorrow', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      await pumpFor(tester, const Duration(milliseconds: 800));
      replies.single.complete(const SpinRefused(SpinRefusal.dailyLimit, status: _capped));
      await pumpFor(tester, const Duration(milliseconds: 1500));

      expect(find.text('Back tomorrow'), findsOneWidget);
      expect(find.text('SPIN'), findsNothing);
      expect(find.text('Spin again'), findsNothing);
      // The price left the shown balance when the spin started. The refusal puts it back.
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('an insufficient balance leaves Get coins, whatever the page showed', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(const SpinRefused(SpinRefusal.insufficientBalance, status: _paid));
      await pumpFor(tester, const Duration(milliseconds: 1500));

      expect(find.text('Get coins'), findsOneWidget);
      expect(find.text('SPIN'), findsNothing);
    });

    testWidgets('a changed price shows the new price and says so', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      replies.single.complete(
        const SpinRefused(
          SpinRefusal.priceChanged,
          status: SpinWheelStatus(freeSpinAvailable: false, paidSpinsLeft: 4, price: 15),
        ),
      );
      await pumpFor(tester, const Duration(milliseconds: 1500));

      expect(find.text('SPIN'), findsOneWidget);
      expect(find.descendant(of: find.bySemanticsLabel('Spin, 15 coins'), matching: find.text('15')), findsWidgets);
      expect(toasts, <String>['The price changed. Check it and spin again.']);
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a failure shows the error toast, restores the balance and lets the user try again', (tester) async {
      status.value = _paid;
      await pumpPage(tester);

      await tapSpin(tester);
      expect(find.text('330'), findsOneWidget);
      replies.single.complete(const SpinFailed('unavailable'));
      await pumpFor(tester, const Duration(milliseconds: 1500));

      expect(toasts, <String>[AppLocalizationsEn().errorNetwork]);
      expect(find.text('340'), findsOneWidget);
      expect(find.text('SPIN'), findsOneWidget);
      expect(haptics, contains('error'));

      await tapSpin(tester);
      expect(maxCosts, <int>[10, 10]);
      replies.last.complete(const SpinFailed('unavailable'));
      await pumpFor(tester, const Duration(seconds: 3));
    });

    testWidgets('a spin function that throws counts as a failure', (tester) async {
      app_state.prismUser.premium = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: kLightTheme,
          home: SpinWheelPage(
            spin: ({required int maxCost}) async => throw StateError('boom'),
            status: status,
            balance: balance,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tapSpin(tester);
      await pumpFor(tester, const Duration(milliseconds: 1500));
      expect(toasts, <String>[AppLocalizationsEn().errorNetwork]);
      await pumpFor(tester, const Duration(seconds: 2));
    });
  });

  group('reduced motion', () {
    testWidgets('the result shows at once, with no wind up, cruise or count up', (tester) async {
      status.value = _paid;
      await pumpPage(tester, reduceMotion: true);

      await tapSpin(tester);
      expect(find.text('330'), findsOneWidget);
      replies.single.complete(_won(4, coins: 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Spin again'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
    });

    testWidgets('a refusal under reduced motion shows its state at once', (tester) async {
      status.value = _paid;
      await pumpPage(tester, reduceMotion: true);

      await tapSpin(tester);
      replies.single.complete(const SpinRefused(SpinRefusal.dailyLimit, status: _capped));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Back tomorrow'), findsOneWidget);
    });
  });

  group('haptics', () {
    testWidgets('a press taps once and every peg pass plays a selection, at most one every 50 ms', (tester) async {
      await pumpPage(tester, pro: true);

      await tapSpin(tester);
      expect(haptics, <String>['tap']);
      for (int i = 0; i < 125; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final int selections = haptics.where((String h) => h == 'selection').length;
      expect(selections, greaterThan(5));
      expect(selections, lessThanOrEqualTo(2000 ~/ 50), reason: 'Two seconds hold at most one selection per 50 ms');
      for (int i = 1; i < selectionTimes.length; i++) {
        expect(
          selectionTimes[i] - selectionTimes[i - 1],
          greaterThanOrEqualTo(const Duration(milliseconds: 50)),
          reason: 'selection $i came too soon after the one before',
        );
      }
      replies.single.complete(const SpinFailed('x'));
      await pumpFor(tester, const Duration(seconds: 2));
    });
  });

  group('the page', () {
    testWidgets('has a close button with a tooltip that leaves the route', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: kLightTheme,
          home: Builder(
            builder: (BuildContext context) =>
                TextButton(onPressed: () => showSpinWheel(context), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Spin the wheel'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('Spin the wheel'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('the odds sheet lists every slice with its odds', (tester) async {
      await pumpPage(tester, pro: true);

      await tester.tap(find.text('See the odds'));
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('The odds'), findsOneWidget);
      for (final String row in <String>[
        '10 coins',
        '1 coin',
        '5 coins',
        '100 coins',
        '20 coins',
        '2 coins',
        '50 coins',
      ]) {
        expect(find.text(row), findsOneWidget);
      }
      expect(find.text('25 XP'), findsNothing);
      expect(find.text('50 XP'), findsNothing);
      expect(find.text('Mystery cosmetic'), findsOneWidget);
      expect(find.text('Pays 50 coins if you own them all'), findsOneWidget);
      for (final String percent in <String>['18%', '22%', '30%', '1%', '8%', '12%', '3%', '6%']) {
        expect(find.text(percent), findsOneWidget);
      }
    });

    testWidgets('a status that changes while idle updates the button', (tester) async {
      await pumpPage(tester, pro: true);
      expect(find.text('Free spin'), findsOneWidget);

      status.value = _capped;
      await tester.pump();
      expect(find.text('Back tomorrow'), findsOneWidget);

      balance.value = 500;
      await tester.pump();
      expect(find.text('500'), findsOneWidget);
    });
  });
}
