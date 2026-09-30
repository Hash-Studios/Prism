import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_collection_section.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_spend_section.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockShopBloc extends MockBloc<StreakShopEvent, StreakShopState> implements StreakShopBloc {}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  tearDown(() async {
    CoinsService.instance.streakNotifier.value = StreakStatus.empty;
    CoinsService.instance.balanceNotifier.value = 0;
    await getIt.reset();
  });

  testWidgets('spend tiles expose a working screen reader tap', (tester) async {
    final handle = tester.ensureSemantics();
    int purchases = 0;
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(RewardsSpendSection(onStreakFreeze: () => purchases++)));

    final SemanticsNode button = tester.getSemantics(find.bySemanticsLabel('Streak freeze, 50 coins'));
    expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: button.id),
    );
    await tester.pump();
    expect(purchases, 1);
    handle.dispose();
  });

  testWidgets('locked collection cards expose the explanation through a screen reader tap', (tester) async {
    final handle = tester.ensureSemantics();
    final bloc = _MockShopBloc();
    whenListen(
      bloc,
      const Stream<StreakShopState>.empty(),
      initialState: const StreakShopState(
        status: StreakShopStatus.success,
        items: <PrismWallpaper>[
          PrismWallpaper(
            core: WallpaperCore(id: 'locked', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
            requiredStreakDays: 30,
            streakShopCoinCost: 500,
          ),
        ],
      ),
    );
    getIt.registerFactory<StreakShopBloc>(() => bloc);
    await tester.pumpWidget(_host(const RewardsCollectionSection()));
    await tester.pump();

    final SemanticsNode button = tester.getSemantics(find.bySemanticsLabel('Wallpaper, locked, Unlocks at 30 days'));
    expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: button.id),
    );
    await tester.pump();
    expect(find.text('Keep your streak for 30 days to unlock this. Or have 500 coins.'), findsOneWidget);
    handle.dispose();
  });
}
