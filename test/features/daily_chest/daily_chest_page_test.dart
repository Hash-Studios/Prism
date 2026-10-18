import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:Prism/features/daily_chest/views/pages/daily_chest_page.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_box.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../qa_render/qa_harness.dart' show loadFonts;
import '../quests/fake_quests_repository.dart';

/// 18:48 UTC: the next chest is in 5h 12m.
final DateTime _now = DateTime.utc(2026, 10, 18, 18, 48);
const String _today = '2026-10-18';

QuestState _quests({int claimed = 0, bool bonusDone = false, bool opened = false, String dayKey = _today}) =>
    questState(
      dayKey: dayKey,
      items: <QuestItem>[
        questItem('set_wall', QuestEvent.setWallpaper, claimed: claimed > 0),
        questItem('fav_3', QuestEvent.favourite, target: 3, claimed: claimed > 1),
        questItem('wotd_view', QuestEvent.viewWotd, claimed: claimed > 2),
      ],
      bonus: questItem('watch_ad', QuestEvent.watchAd, claimed: bonusDone),
      chestOpened: opened,
    );

ChestWon _won(int slot, {int coins = 0, int xp = 0, String? itemId, int cost = 8, bool doubled = false}) => ChestWon(
  win: ChestWin(slot: slot, coins: coins, xp: xp, itemId: itemId),
  cost: cost,
  doubled: doubled,
  slots: defaultChest,
);

/// How visible [finder] is: the product of every fade above it, and 0 when it is not in the tree.
double shown(Finder finder) {
  if (finder.evaluate().isEmpty) return 0;
  double opacity = 1;
  for (final Element fade in find.ancestor(of: finder, matching: find.byType(FadeTransition)).evaluate()) {
    opacity *= (fade.widget as FadeTransition).opacity.value;
  }
  return opacity;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const MethodChannel hapticChannel = MethodChannel('prism/haptics');
  final List<String> toasts = <String>[];
  final List<String> haptics = <String>[];

  late ValueNotifier<QuestState?> quests;
  late ValueNotifier<int> balance;
  late List<int> maxCosts;
  late List<Completer<DailyChestResult>> replies;
  late int refreshes;
  late int shopOpens;
  late DateTime clock;

  setUpAll(loadFonts);

  setUp(() {
    toasts.clear();
    haptics.clear();
    quests = ValueNotifier<QuestState?>(_quests());
    balance = ValueNotifier<int>(340);
    maxCosts = <int>[];
    replies = <Completer<DailyChestResult>>[];
    refreshes = 0;
    shopOpens = 0;
    clock = _now;
    PrismHaptics.enabled = true;
    final TestDefaultBinaryMessengerBinding binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (MethodCall call) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, (MethodCall call) async {
      if (call.method == 'play') haptics.add(call.arguments as String);
      return null;
    });
  });

  tearDown(() {
    final TestDefaultBinaryMessengerBinding binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, null);
    quests.dispose();
    balance.dispose();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  /// Like the coins service, a win moves the balance before the reply reaches the page.
  Future<DailyChestResult> open({required int maxCost}) {
    maxCosts.add(maxCost);
    final Completer<DailyChestResult> reply = Completer<DailyChestResult>();
    replies.add(reply);
    return reply.future.then((DailyChestResult result) {
      if (result is ChestWon) balance.value += result.win.coins - result.cost;
      return result;
    });
  }

  DailyChestPage page() => DailyChestPage(
    open: open,
    quests: quests,
    balance: balance,
    now: () => clock,
    refresh: () async => refreshes++,
    onOpenShop: () => shopOpens++,
  );

  /// 50 ms frames. The box loops for ever, so `pumpAndSettle` would time out.
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    for (Duration t = Duration.zero; t < total; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpPage(WidgetTester tester, {bool reduceMotion = false, Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reduceMotion),
        child: MaterialApp(theme: kLightTheme, home: page()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// The page is on top of a route, so closing it can be seen.
  Future<NavigatorState> pumpRouted(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: kLightTheme, home: const SizedBox()));
    final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push<void>(MaterialPageRoute<void>(builder: (_) => page())));
    await pumpFor(tester, const Duration(milliseconds: 500));
    return navigator;
  }

  Future<void> pumpUntil(WidgetTester tester, Finder finder, {int maxFrames = 200}) async {
    for (int i = 0; i < maxFrames && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  ChestPhase phase(WidgetTester tester) => tester.widget<ChestBox>(find.byType(ChestBox)).phase;

  /// Taps Open, answers with [result] and runs the page until the box has opened and the exits are on screen.
  Future<void> openWith(WidgetTester tester, DailyChestResult result, {String label = 'Open'}) async {
    await tester.tap(find.text(label));
    await tester.pump();
    replies.single.complete(result);
    await pumpUntil(tester, find.text('Done'));
    await pumpFor(tester, const Duration(seconds: 1));
  }

  group('what the page says', () {
    testWidgets('a paid chest shows the price, what it costs and the way to open it free', (tester) async {
      await pumpPage(tester);

      expect(find.text('Daily chest'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.bySemanticsLabel('Open the chest, 8 coins'), findsOneWidget);
      expect(find.text('Open it for 8 coins, or finish 3 more quests to open it free.'), findsOneWidget);
      expect(find.text("Do today's bonus quest first to double it."), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
      expect(find.text('See the odds'), findsOneWidget);
      expect(phase(tester), ChestPhase.ready);
    });

    testWidgets('a free chest reads Open free and says the quests made it free', (tester) async {
      quests.value = _quests(claimed: 3, bonusDone: true);
      await pumpPage(tester);

      expect(find.text('Open free'), findsOneWidget);
      expect(find.text('Your quests made it free today.'), findsOneWidget);
      expect(find.text('Bonus quest done: coins and XP are doubled.'), findsOneWidget);
      expect(find.bySemanticsLabel('Open the chest, free'), findsOneWidget);
    });

    testWidgets('an opened chest is spent: it says when the next one comes and the button is disabled', (tester) async {
      quests.value = _quests(claimed: 3, opened: true);
      await pumpPage(tester);

      expect(find.text('Back tomorrow'), findsOneWidget);
      expect(find.text('Opened. A new chest in 5h 12m.'), findsOneWidget);
      expect(find.textContaining('bonus quest'), findsNothing);
      expect(find.text('See the odds'), findsOneWidget);
      expect(phase(tester), ChestPhase.spent);
      await tester.tap(find.text('Back tomorrow'));
      await tester.pump();
      expect(maxCosts, isEmpty);
    });

    testWidgets('a short balance reads Get coins and the pill warns', (tester) async {
      balance.value = 4;
      await pumpPage(tester);

      expect(find.text('Get coins'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('Get coins opens a sheet that offers a video and sends no chest', (tester) async {
      balance.value = 4;
      await pumpPage(tester);

      await tester.tap(find.text('Get coins'));
      await tester.pump();
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('Not enough coins'), findsOneWidget);
      expect(find.text('The chest costs 8 coins. You have 4. Watch a video to earn more.'), findsOneWidget);
      expect(maxCosts, isEmpty);
      await tester.tap(find.text('Not now'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('Not enough coins'), findsNothing);
    });

    testWidgets('with no quests for today the button waits, and the page asks for them', (tester) async {
      quests.value = null;
      await pumpPage(tester);

      expect(refreshes, 1);
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(maxCosts, isEmpty);
      expect(phase(tester), ChestPhase.ready);

      quests.value = _quests(claimed: 3);
      await tester.pump();
      expect(find.text('Open free'), findsOneWidget);
    });

    testWidgets('quests of an earlier day do not count as today', (tester) async {
      quests.value = questState(dayKey: '2026-10-17');
      await pumpPage(tester);

      expect(refreshes, 1);
      expect(find.text('Your quests made it free today.'), findsNothing);
    });

    testWidgets('the odds sheet lists every slot, grouped by tier', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('See the odds'));
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('The odds'), findsOneWidget);
      expect(find.text('Every chest pays something.'), findsOneWidget);
      for (final String tier in <String>['Common', 'Rare', 'Epic', 'Legendary']) {
        expect(find.text(tier), findsOneWidget);
      }
      expect(find.text('58%'), findsOneWidget);
      for (final String row in <String>['5 coins', '10 coins', '25 XP', '20 coins', '40 coins', '100 coins']) {
        expect(find.text(row), findsOneWidget);
      }
      expect(find.text('Mystery cosmetic'), findsOneWidget);
      expect(find.text('Pays 25 coins if you own them all'), findsOneWidget);
    });

    testWidgets('the odds slot keeps its top and its height after a win, with nothing in it', (tester) async {
      await pumpPage(tester);
      const Key slot = ValueKey<String>('odds_slot');
      final (double, double) ready = (tester.getTopLeft(find.byKey(slot)).dy, tester.getSize(find.byKey(slot)).height);

      await openWith(tester, _won(3, coins: 20));

      expect(find.text('See the odds'), findsNothing);
      expect((tester.getTopLeft(find.byKey(slot)).dy, tester.getSize(find.byKey(slot)).height), ready);
      expect(ready.$2, 44);
    });

    testWidgets('the close button has a tooltip and leaves the page', (tester) async {
      final NavigatorState navigator = await pumpRouted(tester);

      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(DailyChestPage), findsNothing);
      expect(navigator.canPop(), isFalse);
    });
  });

  group('opening', () {
    testWidgets('a tap sends the price it shows, charges the box and takes the price off the balance', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(maxCosts, <int>[8]);
      expect(phase(tester), ChestPhase.charging);
      expect(haptics, <String>['tap']);
      expect(find.text('332'), findsOneWidget);
      expect(find.text('340'), findsNothing);
      replies.single.complete(const ChestFailed('timeout'));
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a free chest sends a max cost of 0 and keeps the balance', (tester) async {
      quests.value = _quests(claimed: 3);
      await pumpPage(tester);

      await tester.tap(find.text('Open free'));
      await tester.pump();

      expect(maxCosts, <int>[0]);
      expect(find.text('340'), findsOneWidget);
      replies.single.complete(const ChestFailed('timeout'));
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a quick reply still waits for the shake: the box opens only after 600 ms', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(_won(3, coins: 20));
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(phase(tester), ChestPhase.charging);
      expect(find.text('See the odds'), findsNothing);

      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(phase(tester), ChestPhase.opening);
      expect(find.text('See the odds'), findsNothing);
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('one press sends one request, however many times it is tapped', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.tap(find.text('Open'), warnIfMissed: false);
      await tester.pump();

      expect(maxCosts, <int>[8]);
      replies.single.complete(const ChestFailed('timeout'));
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('the close button is dimmed and says it is disabled while the box works, and wakes once revealed', (
      tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final NavigatorState navigator = await pumpRouted(tester);
      final Finder close = find.byTooltip('Close');
      Matcher closeSemantics({required bool enabled}) =>
          isSemantics(isButton: true, hasEnabledState: true, isEnabled: enabled);

      expect(tester.getSemantics(close), closeSemantics(enabled: true));

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(tester.getSemantics(close), closeSemantics(enabled: false));
      expect(tester.widget<IconButton>(find.ancestor(of: close, matching: find.byType(IconButton))).onPressed, isNull);
      await tester.tap(close, warnIfMissed: false);
      await tester.pump();
      expect(find.byType(DailyChestPage), findsOneWidget);

      replies.single.complete(_won(3, coins: 20));
      await pumpUntil(tester, find.text('Done'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(tester.getSemantics(close), closeSemantics(enabled: true));
      await tester.tap(close);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(DailyChestPage), findsNothing);
      expect(navigator.canPop(), isFalse);
      semantics.dispose();
    });

    testWidgets('back does not close the page while the box charges or opens, and does once it is revealed', (
      tester,
    ) async {
      final NavigatorState navigator = await pumpRouted(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(await navigator.maybePop(), isTrue);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.byType(DailyChestPage), findsOneWidget);

      replies.single.complete(_won(3, coins: 20));
      await pumpFor(tester, const Duration(milliseconds: 900));
      expect(phase(tester), ChestPhase.opening);
      expect(await navigator.maybePop(), isTrue);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byType(DailyChestPage), findsOneWidget);

      await pumpUntil(tester, find.text('Done'));
      expect(await navigator.maybePop(), isTrue);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(DailyChestPage), findsNothing);
    });
  });

  group('a prize', () {
    testWidgets('coins show their tier, count up and land on the balance', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(_won(3, coins: 20));
      // The reply is in and the box is still charging: no prize yet.
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('Rare'), findsNothing);
      expect(find.text('332'), findsOneWidget);

      await pumpUntil(tester, find.text('Rare'));
      await pumpFor(tester, const Duration(seconds: 2));
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('See the odds'), findsNothing);
      expect(find.text('See it in the Shop'), findsNothing);
      expect(find.text('Doubled by your bonus quest'), findsNothing);
      expect(find.text('352'), findsOneWidget);
      expect(phase(tester), ChestPhase.revealed);
      expect(haptics, <String>['tap', 'success']);
      expect(tester.widget<ChestBox>(find.byType(ChestBox)).glow, const Color(0xFF38BDF8));
    });

    testWidgets('the prize appears at the burst, before the box has finished opening', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(_won(3, coins: 20));
      await pumpFor(tester, const Duration(milliseconds: 650));
      expect(find.text('Rare'), findsNothing);

      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(phase(tester), ChestPhase.opening);
      expect(find.text('Rare'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a bonus quest that doubled the chest says so', (tester) async {
      quests.value = _quests(claimed: 3, bonusDone: true);
      await pumpPage(tester);

      await openWith(tester, _won(3, coins: 40, cost: 0, doubled: true), label: 'Open free');

      expect(find.text('+40'), findsOneWidget);
      expect(find.text('Doubled by your bonus quest'), findsOneWidget);
      expect(find.text('380'), findsOneWidget);
    });

    testWidgets('100 coins is legendary', (tester) async {
      await pumpPage(tester);

      await openWith(tester, _won(6, coins: 100));

      expect(find.text('Legendary'), findsOneWidget);
      expect(find.text('+100'), findsOneWidget);
      expect(tester.widget<ChestBox>(find.byType(ChestBox)).glow, const Color(0xFFF5B83D));
    });

    testWidgets('XP shows +N XP and does not touch the balance beyond the price', (tester) async {
      await pumpPage(tester);

      await openWith(tester, _won(2, xp: 25));

      expect(find.text('+25 XP'), findsOneWidget);
      expect(find.text('Rare'), findsOneWidget);
      expect(find.text('332'), findsOneWidget);
    });

    testWidgets('a cosmetic names the item and its kind, and offers the Shop', (tester) async {
      await pumpPage(tester);

      await openWith(tester, _won(4, itemId: 'frame_ring'));

      expect(find.text('Epic'), findsOneWidget);
      expect(find.text('Ring'), findsOneWidget);
      expect(find.text('New frame'), findsOneWidget);
      expect(find.text('See it in the Shop'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('332'), findsOneWidget);
    });

    testWidgets('See it in the Shop closes the page and then opens the Shop', (tester) async {
      await pumpRouted(tester);

      await openWith(tester, _won(4, itemId: 'frame_ring'));
      await tester.tap(find.text('See it in the Shop'));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(find.byType(DailyChestPage), findsNothing);
      expect(shopOpens, 1);
    });

    testWidgets('a cosmetic that pays coins says every one is owned, with no Shop button', (tester) async {
      await pumpPage(tester);

      await openWith(tester, _won(4, coins: 25));

      expect(find.text('+25'), findsOneWidget);
      expect(find.text('You own every cosmetic'), findsOneWidget);
      expect(find.text('See it in the Shop'), findsNothing);
      expect(find.text('357'), findsOneWidget);
    });

    testWidgets('Done closes the page', (tester) async {
      await pumpRouted(tester);

      await openWith(tester, _won(0, coins: 5));
      expect(find.text('Common'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(find.byType(DailyChestPage), findsNothing);
    });
  });

  group('the open motion', () {
    /// Taps Open, answers with a Rare win and calls [onFrame] after every 16 ms frame until Done is fully in.
    Future<void> filmOpen(WidgetTester tester, VoidCallback onFrame) async {
      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(_won(3, coins: 20));
      for (int frames = 0; shown(find.text('Done')) < 1; frames++) {
        expect(frames, lessThan(400), reason: 'Done never came in');
        await tester.pump(const Duration(milliseconds: 16));
        onFrame();
      }
      await pumpFor(tester, const Duration(seconds: 3));
    }

    testWidgets('Open is gone before Done fades in, and Done shows only once revealed', (tester) async {
      await pumpPage(tester);
      bool openSeen = false;
      int framesSincePrize = 0;

      await filmOpen(tester, () {
        final double open = shown(find.text('Open'));
        final double done = shown(find.text('Done'));
        openSeen = openSeen || open == 1;
        expect(open > 0 && done > 0, isFalse, reason: 'Open at $open and Done at $done in one frame');
        if (find.text('Done').evaluate().isNotEmpty) expect(phase(tester), ChestPhase.revealed);
        if (find.text('Rare').evaluate().isNotEmpty && ++framesSincePrize > 12) {
          expect(open, 0, reason: 'Open still shows ${framesSincePrize * 16} ms after the prize came up');
        }
      });

      expect(openSeen, isTrue);
      expect(framesSincePrize, greaterThan(12));
    });

    testWidgets('the title is gone before the prize card rises', (tester) async {
      await pumpPage(tester);
      expect(shown(find.text('Daily chest')), 1);
      bool cardSeen = false;

      await filmOpen(tester, () {
        if (cardSeen || find.text('Rare').evaluate().isEmpty) return;
        cardSeen = true;
        expect(shown(find.text('Daily chest')), 0, reason: 'the title is still on screen when the card rises');
      });

      expect(cardSeen, isTrue);
    });

    testWidgets('the aura goes from the accent to the Rare blue without a washed-out frame', (tester) async {
      await pumpPage(tester);
      HSVColor aura() {
        final DecoratedBox box = tester.widget<DecoratedBox>(find.byKey(const ValueKey<String>('aura')));
        return HSVColor.fromColor(((box.decoration as BoxDecoration).gradient! as RadialGradient).colors.first);
      }

      final List<HSVColor> frames = <HSVColor>[aura()];
      await filmOpen(tester, () => frames.add(aura()));

      // The accent is 0.48 saturated and Rare is 0.77.
      final double least = frames.map((HSVColor c) => c.saturation).reduce((double a, double b) => a < b ? a : b);
      expect(least, greaterThanOrEqualTo(0.48), reason: 'a frame of the aura is washed out');
      expect(frames.last.hue, closeTo(198.4, 1));
    });
  });

  group('refusals and failures', () {
    testWidgets('an insufficient balance puts the price back and leaves Get coins', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(const ChestRefused(ChestRefusal.insufficientBalance));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(phase(tester), ChestPhase.ready);
      expect(find.text('Get coins'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('a changed price shows the new price and says so', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(const ChestRefused(ChestRefusal.priceChanged, price: 12));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(toasts, <String>['The price changed. Check it and open again.']);
      expect(find.text('Open it for 12 coins, or finish 3 more quests to open it free.'), findsOneWidget);
      expect(find.bySemanticsLabel('Open the chest, 12 coins'), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a chest that is open already turns the page to spent through the quests the refusal brought', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      quests.value = _quests(opened: true);
      replies.single.complete(const ChestRefused(ChestRefusal.alreadyOpened));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(phase(tester), ChestPhase.spent);
      expect(find.text('Back tomorrow'), findsOneWidget);
      expect(find.text('Opened. A new chest in 5h 12m.'), findsOneWidget);
      expect(refreshes, 0);
      expect(find.text('340'), findsOneWidget);
    });

    testWidgets('a free chest the server prices after all becomes a paid chest, so the next tap sends the price', (
      tester,
    ) async {
      quests.value = _quests(claimed: 3);
      await pumpPage(tester);
      expect(find.text('Open free'), findsOneWidget);

      await tester.tap(find.text('Open free'));
      await tester.pump();
      quests.value = _quests();
      replies.single.complete(const ChestRefused(ChestRefusal.priceChanged, price: 8));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(find.text('Open free'), findsNothing);
      expect(find.bySemanticsLabel('Open the chest, 8 coins'), findsOneWidget);
      expect(find.text('Open it for 8 coins, or finish 3 more quests to open it free.'), findsOneWidget);

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(maxCosts, <int>[0, 8]);
      replies.last.complete(const ChestFailed('timeout'));
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a price the server named lasts until the UTC day changes', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(const ChestRefused(ChestRefusal.priceChanged, price: 12));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Open it for 12 coins, or finish 3 more quests to open it free.'), findsOneWidget);

      clock = DateTime.utc(2026, 10, 19, 0, 5);
      quests.value = _quests(dayKey: '2026-10-19');
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('Open it for 8 coins, or finish 3 more quests to open it free.'), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a failure shows the error toast, restores the balance and lets the user try again', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.text('332'), findsOneWidget);
      replies.single.complete(const ChestFailed('unavailable'));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(toasts, <String>["Couldn't reach Prism. Try again."]);
      expect(phase(tester), ChestPhase.ready);
      expect(find.text('340'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(haptics, contains('error'));

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(maxCosts, <int>[8, 8]);
      replies.last.complete(const ChestFailed('unavailable'));
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('a failure shows the quests that arrived while the box charged', (tester) async {
      quests.value = _quests(claimed: 3);
      await pumpPage(tester);

      await tester.tap(find.text('Open free'));
      await tester.pump();
      quests.value = _quests();
      replies.single.complete(const ChestFailed('unavailable'));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Open free'), findsNothing);
      await pumpFor(tester, const Duration(seconds: 2));
    });

    testWidgets('an open function that throws counts as a failure', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: kLightTheme,
          home: DailyChestPage(
            open: ({required int maxCost}) async => throw StateError('boom'),
            quests: quests,
            balance: balance,
            now: () => _now,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Open'));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(toasts, <String>["Couldn't reach Prism. Try again."]);
      expect(phase(tester), ChestPhase.ready);
      await pumpFor(tester, const Duration(seconds: 2));
    });
  });

  group('reduced motion', () {
    testWidgets('the prize shows at once, with no shake, no wait and no animation', (tester) async {
      await pumpPage(tester, reduceMotion: true);

      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(find.text('332'), findsOneWidget);
      replies.single.complete(_won(3, coins: 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Rare'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('See the odds'), findsNothing);
      expect(find.text('352'), findsOneWidget);
      expect(phase(tester), ChestPhase.revealed);
    });

    testWidgets('turning it on while the box opens still shows the prize, and the page can close', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
      Widget app({required bool reduceMotion}) => MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
        child: MaterialApp(theme: kLightTheme, navigatorKey: navigator, home: const SizedBox()),
      );
      await tester.pumpWidget(app(reduceMotion: false));
      unawaited(navigator.currentState!.push<void>(MaterialPageRoute<void>(builder: (_) => page())));
      await pumpFor(tester, const Duration(milliseconds: 500));

      await tester.tap(find.text('Open'));
      await tester.pump();
      replies.single.complete(_won(3, coins: 20));
      await pumpFor(tester, const Duration(milliseconds: 800));
      expect(phase(tester), ChestPhase.opening);
      expect(find.text('Done'), findsNothing);

      await tester.pumpWidget(app(reduceMotion: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(phase(tester), ChestPhase.revealed);
      expect(find.text('Rare'), findsOneWidget);
      expect(find.text('352'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(DailyChestPage), findsNothing);
    });

    testWidgets('a refusal under reduced motion shows its state at once', (tester) async {
      await pumpPage(tester, reduceMotion: true);

      await tester.tap(find.text('Open'));
      await tester.pump();
      quests.value = _quests(opened: true);
      replies.single.complete(const ChestRefused(ChestRefusal.alreadyOpened));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('Back tomorrow'), findsOneWidget);
    });
  });

  group('the page follows the coins service while idle', () {
    testWidgets('a balance change updates the pill and the button', (tester) async {
      await pumpPage(tester);
      expect(find.text('Open'), findsOneWidget);

      balance.value = 3;
      await tester.pump();
      expect(find.text('Get coins'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a chest opened on another device turns the page to spent', (tester) async {
      await pumpPage(tester);

      quests.value = _quests(opened: true);
      await tester.pump();

      expect(find.text('Back tomorrow'), findsOneWidget);
      expect(phase(tester), ChestPhase.spent);
    });
  });

  group('small screens', () {
    for (final Size size in const <Size>[Size(320, 568), Size(390, 667)]) {
      for (final double scale in const <double>[1, 1.3]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} at text scale $scale fits, ready and revealed', (
          tester,
        ) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
              child: MaterialApp(theme: kLightTheme, home: page()),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Open'));
          await tester.pump();
          replies.single.complete(_won(4, itemId: 'frame_ring'));
          await pumpUntil(tester, find.text('Done'));
          await pumpFor(tester, const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
