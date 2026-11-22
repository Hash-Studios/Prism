import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/features/coin_packs/coin_packs.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

final List<CoinPack> _packs = <CoinPack>[
  const CoinPack(
    def: CoinPackDef(productId: 'prism_coins_100', coins: 100),
    priceString: r'$0.99',
  ),
  const CoinPack(
    def: CoinPackDef(productId: 'prism_coins_300', coins: 330, bonusPercent: 10),
    priceString: r'$2.99',
  ),
  const CoinPack(
    def: CoinPackDef(productId: 'prism_coins_700', coins: 840, bonusPercent: 20),
    priceString: r'$6.99',
  ),
  const CoinPack(
    def: CoinPackDef(productId: 'prism_coins_1600', coins: 2080, bonusPercent: 30),
    priceString: r'$14.99',
  ),
];

class _FakeGateway implements CoinPackGateway {
  _FakeGateway({this.failLoads = 0});

  List<CoinPack> availablePacks = _packs;
  int failLoads;
  int loadCalls = 0;
  int buyCalls = 0;
  Completer<CoinPackPurchaseResult> _buy = Completer<CoinPackPurchaseResult>();

  @override
  Future<List<CoinPack>> loadPacks() async {
    loadCalls++;
    if (failLoads > 0) {
      failLoads--;
      throw const CoinPackLoadException('offline');
    }
    return availablePacks;
  }

  @override
  Future<CoinPackPurchaseResult> buy(CoinPack pack, {VoidCallback? onVerifying}) {
    buyCalls++;
    _buy = Completer<CoinPackPurchaseResult>();
    return _buy.future;
  }

  void finish(CoinPackPurchaseResult result) => _buy.complete(result);
}

// PrismSheetBody needs a sheet route above it, so the sheet opens through showPrismSheet like the app does.
Future<void> _pumpSheet(WidgetTester tester, CoinPackGateway gateway, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kLightTheme,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showPrismSheet<void>(
              context,
              builder: (BuildContext _) => CoinPacksSheet(source: 'test', gateway: gateway),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tapPack(WidgetTester tester, String productId) async {
  await tester.tap(find.byKey(ValueKey<String>('coin-pack-$productId')));
  await tester.pump();
  await tester.pump();
}

bool _rowEnabled(WidgetTester tester, String productId) {
  final Finder row = find.byKey(ValueKey<String>('coin-pack-$productId'));
  return tester.widget<InkWell>(find.descendant(of: row, matching: find.byType(InkWell))).onTap != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(AnalyticsRuntime.reset);

  testWidgets('shows the four packs with coins, bonus and price', (WidgetTester tester) async {
    final _FakeGateway gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);

    expect(find.text(_l10n.coinPacksCoins(100)), findsOneWidget);
    expect(find.text(_l10n.coinPacksCoins(330)), findsOneWidget);
    expect(find.text(_l10n.coinPacksCoins(840)), findsOneWidget);
    expect(find.text(_l10n.coinPacksCoins(2080)), findsOneWidget);
    expect(find.text(_l10n.coinPacksBonus(10)), findsOneWidget);
    expect(find.text(_l10n.coinPacksBonus(20)), findsOneWidget);
    expect(find.text(_l10n.coinPacksBonus(30)), findsOneWidget);
    expect(find.text(r'$0.99'), findsOneWidget);
    expect(find.text(r'$2.99'), findsOneWidget);
    expect(find.text(r'$6.99'), findsOneWidget);
    expect(find.text(r'$14.99'), findsOneWidget);
    expect(analytics.events.whereType<CoinPackViewedEvent>().single.packCount, 4);
  });

  testWidgets('load failure shows the error and Retry loads again', (WidgetTester tester) async {
    final _FakeGateway gateway = _FakeGateway(failLoads: 1);
    await _pumpSheet(tester, gateway);

    expect(find.text(_l10n.coinPacksLoadFailed), findsOneWidget);
    expect(find.text(_l10n.coinPacksRetry), findsOneWidget);
    expect(analytics.events.whereType<CoinPackViewedEvent>().single.packCount, 0);

    await tester.tap(find.text(_l10n.coinPacksRetry));
    await tester.pump();
    await tester.pump();

    expect(gateway.loadCalls, 2);
    expect(find.text(_l10n.coinPacksLoadFailed), findsNothing);
    expect(find.text(r'$0.99'), findsOneWidget);
    expect(analytics.events.whereType<CoinPackViewedEvent>(), hasLength(1));
  });

  testWidgets('cancelled purchase returns to the list with no error', (WidgetTester tester) async {
    final _FakeGateway gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);

    await _tapPack(tester, 'prism_coins_300');
    gateway.finish(const CoinPackCancelled());
    await tester.pump();
    await tester.pump();

    expect(find.text(r'$2.99'), findsOneWidget);
    expect(find.text(_l10n.coinPacksFailed), findsNothing);
    expect(_rowEnabled(tester, 'prism_coins_100'), isTrue);
    expect(analytics.events.whereType<CoinPackPurchasedEvent>().single.outcome, CoinPackOutcomeValue.cancelled);
  });

  for (final switched in [false, true]) {
    testWidgets('dismissed purchase tracks its outcome only for the buyer (account switched: $switched)', (
      tester,
    ) async {
      final previous = app_state.prismUser;
      addTearDown(() => app_state.prismUser = previous);
      app_state.prismUser = profileUser(id: 'buyer');
      final gateway = _FakeGateway();
      await _pumpSheet(tester, gateway);
      await _tapPack(tester, 'prism_coins_100');
      Navigator.of(tester.element(find.byType(CoinPacksSheet))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CoinPacksSheet), findsNothing);

      if (switched) app_state.prismUser = profileUser(id: 'next-user');
      gateway.finish(const CoinPackGranted(coins: 100, balance: 110));
      await tester.pump();
      final outcomes = analytics.events.whereType<CoinPackPurchasedEvent>();
      if (switched) {
        expect(outcomes, isEmpty);
      } else {
        expect(outcomes.single.outcome, CoinPackOutcomeValue.granted);
      }
    });
  }

  testWidgets('pending purchase shows the pending text and Done', (WidgetTester tester) async {
    final _FakeGateway gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);

    await _tapPack(tester, 'prism_coins_100');
    gateway.finish(const CoinPackPending());
    await tester.pump();
    await tester.pump();

    expect(find.text(_l10n.coinPacksPending), findsOneWidget);
    expect(find.text(_l10n.coinPacksDone), findsOneWidget);

    await tester.tap(find.text(_l10n.coinPacksDone));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CoinPacksSheet), findsNothing);
  });

  testWidgets('granted purchase shows the new balance', (WidgetTester tester) async {
    final _FakeGateway gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);

    await _tapPack(tester, 'prism_coins_300');
    gateway.finish(const CoinPackGranted(coins: 330, balance: 380));
    await tester.pump();
    await tester.pump();

    expect(find.text(_l10n.coinPacksSuccess(330, 380)), findsOneWidget);
    expect(find.text(_l10n.coinPacksDone), findsOneWidget);
    expect(find.text(r'$2.99'), findsNothing);
  });

  testWidgets('a changed offer reloads the remaining packs without buying again', (tester) async {
    final gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);
    await _tapPack(tester, 'prism_coins_100');

    gateway.availablePacks = [_packs[1]];
    gateway.finish(const CoinPackFailed('offer_changed'));
    await tester.pump();
    await tester.pump();

    expect(find.text(r'$0.99'), findsNothing);
    expect(_rowEnabled(tester, 'prism_coins_300'), isTrue);
    expect(gateway.buyCalls, 1);
  });

  testWidgets('failed purchase shows the failure under the list', (WidgetTester tester) async {
    final _FakeGateway gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);

    await _tapPack(tester, 'prism_coins_700');
    gateway.finish(const CoinPackFailed('x'));
    await tester.pump();
    await tester.pump();

    expect(find.text(_l10n.coinPacksFailed), findsOneWidget);
    expect(find.text(r'$6.99'), findsOneWidget);
    expect(_rowEnabled(tester, 'prism_coins_700'), isTrue);
  });

  testWidgets('a screen reader can buy a pack through the row tap action', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    bool semanticsDisposed = false;
    addTearDown(() {
      if (!semanticsDisposed) semantics.dispose();
    });
    final _FakeGateway gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);

    tester.semantics.tap(find.semantics.byLabel(_l10n.coinPacksBuyLabel(330, r'$2.99')));
    await tester.pump();

    expect(gateway.buyCalls, 1);
    for (final CoinPack pack in _packs) {
      final SemanticsData row = tester
          .getSemantics(find.byKey(ValueKey<String>('coin-pack-${pack.productId}')))
          .getSemanticsData();
      expect(row.hasAction(SemanticsAction.tap), isFalse, reason: '${pack.productId} must be disabled while buying');
    }
    semantics.dispose();
    semanticsDisposed = true;
  });

  testWidgets('a second tap while purchasing does not start another buy', (WidgetTester tester) async {
    final _FakeGateway gateway = _FakeGateway();
    await _pumpSheet(tester, gateway);

    await _tapPack(tester, 'prism_coins_100');
    expect(_rowEnabled(tester, 'prism_coins_300'), isFalse);
    await _tapPack(tester, 'prism_coins_300');

    expect(gateway.buyCalls, 1);
    expect(find.text(_l10n.coinPacksPurchasing), findsOneWidget);
  });

  testWidgets('large text lays out the packs without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSheet(tester, _FakeGateway(), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('coin-pack-prism_coins_1600'), skipOffstage: false), findsOneWidget);
    expect(find.text(r'$14.99', skipOffstage: false), findsOneWidget);
  });
}
