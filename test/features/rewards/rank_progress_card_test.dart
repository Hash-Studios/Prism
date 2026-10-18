import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/rewards/domain/rank_progress.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_sheet.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockShopBloc extends MockBloc<ShopEvent, ShopState> implements ShopBloc {}

void main() {
  tearDown(() async {
    CoinsService.instance.xpNotifier.value = XpStatus.empty();
    CoinsService.instance.inventoryNotifier.value = Inventory.empty;
    EconomyConfig.resetForTest();
    await getIt.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    int xp = 500,
    Set<String> owned = const <String>{},
    EconomyConfig config = EconomyConfig.defaults,
    ThemeData? theme,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme ?? kLightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: XpProgressCard(
              progress: RankProgress(xp: xp, owned: owned, config: config),
              onUseReward: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('earned reward is syncing until authoritative inventory confirms it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RankProgressCard())));
    CoinsService.instance.xpNotifier.value = XpStatus(xp: 500, weekXp: 25, rank: EconomyConfig.current.rankFor(500));
    await tester.pump();
    expect(find.text('Aurora name glow earned'), findsOneWidget);
    expect(find.textContaining('Syncing to your inventory'), findsOneWidget);
    CoinsService.instance.inventoryNotifier.value = const Inventory(owned: <String>{'glow_aurora'});
    await tester.pump();
    expect(find.textContaining('Syncing to your inventory'), findsNothing);
    expect(find.text('Next reward: Gold frame'), findsOneWidget);
  });

  testWidgets('explanation opens from accessible info button and explains XP versus coins', (tester) async {
    await pump(tester);
    final Size infoTarget = tester.getSize(find.byTooltip('How XP and rank rewards work'));
    expect(infoTarget.width, greaterThanOrEqualTo(48));
    expect(infoTarget.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byTooltip('How XP and rank rewards work'));
    await tester.pumpAndSettle();
    expect(find.text('XP, ranks & rewards'), findsOneWidget);
    expect(find.textContaining('resets every Monday at 00:00 UTC'), findsOneWidget);
    expect(find.textContaining('Spending coins never lowers your XP'), findsOneWidget);
    expect(find.textContaining('cost no coins and stay yours'), findsOneWidget);
    expect(find.textContaining('Daily quests award 25 XP'), findsOneWidget);
    expect(find.textContaining('Daily streaks earn 5 XP'), findsOneWidget);
    expect(find.textContaining('Quest chests earn 10 XP'), findsOneWidget);
    expect(find.textContaining('Ads, Pro spins, Pro daily bonuses, referrals and refunds earn no XP.'), findsOneWidget);
  });

  testWidgets('public rank opens explanation without a private inventory claim', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RankInfoChip(xp: 2500))));
    await tester.tap(find.text('Gold'));
    await tester.pumpAndSettle();
    expect(find.text('XP, ranks & rewards'), findsOneWidget);
    expect(find.textContaining('Syncing'), findsNothing);
  });

  testWidgets('Use opens the latest confirmed rank reward directly with Equip', (tester) async {
    const Set<String> owned = <String>{'glow_aurora', 'frame_gold'};
    final _MockShopBloc bloc = _MockShopBloc();
    whenListen(
      bloc,
      const Stream<ShopState>.empty(),
      initialState: ShopState.initial().copyWith(owned: owned, rankId: 'gold'),
    );
    getIt.registerFactory<ShopBloc>(() => bloc);
    CoinsService.instance.xpNotifier.value = XpStatus.fromUserData(<String, dynamic>{'xp': 2500});
    CoinsService.instance.inventoryNotifier.value = const Inventory(owned: owned);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: RankProgressCard())),
      ),
    );
    await tester.tap(find.text('Use Gold frame'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemSheet), findsOneWidget);
    expect(tester.widget<ShopItemSheet>(find.byType(ShopItemSheet)).item.id, 'frame_gold');
    expect(find.text('Equip'), findsOneWidget);
    expect(find.textContaining('Buy for'), findsNothing);
  });

  testWidgets('custom highest rank is named and has full progress', (tester) async {
    const EconomyConfig config = EconomyConfig(
      xp: EconomyXp(
        ranks: <RankDef>[
          RankDef(id: 'newcomer', min: 0),
          RankDef(id: 'curator', min: 200),
        ],
      ),
    );
    await pump(tester, xp: 300, config: config);
    expect(find.text('Curator'), findsOneWidget);
    expect(find.text('Highest rank reached'), findsOneWidget);
    expect(find.textContaining('Prism'), findsNothing);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 1);
  });

  testWidgets('a config refresh recomputes the live rank and keeps next rank distinct from reward', (tester) async {
    CoinsService.instance.xpNotifier.value = XpStatus.fromUserData(<String, dynamic>{'xp': 70});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RankProgressCard())));
    EconomyConfig.current = const EconomyConfig(
      xp: EconomyXp(
        ranks: <RankDef>[
          RankDef(id: 'bronze', min: 0),
          RankDef(id: 'collector', min: 100),
          RankDef(id: 'silver', min: 700),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('30 XP to Collector'), findsOneWidget);
    expect(find.text('Next reward: Aurora name glow'), findsOneWidget);
    expect(find.text('Yours automatically at Silver · 700 XP'), findsOneWidget);
    CoinsService.instance.xpNotifier.value = XpStatus.fromUserData(<String, dynamic>{'xp': 800});
    await tester.pump();
    expect(find.text('Silver'), findsOneWidget);
    expect(find.text('Highest rank reached'), findsOneWidget);
  });

  for (final ThemeData theme in <ThemeData>[kLightTheme, kDarkTheme]) {
    testWidgets('card and explanation fit 320px at 2x text (${theme.brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, xp: 1999, owned: <String>{'glow_aurora'}, theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('How XP and rank rewards work'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
