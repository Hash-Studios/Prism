import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/rewards/views/widgets/balance_card.dart';
import 'package:Prism/features/rewards/views/widgets/freeze_card.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_hero.dart';
import 'package:Prism/features/streak/bloc/streak_shop_bloc.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

class _MockShopBloc extends MockBloc<StreakShopEvent, StreakShopState> implements StreakShopBloc {}

PrismWallpaper _shopWallpaper() => const PrismWallpaper(
  core: WallpaperCore(id: 'shop-wall', source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: ''),
  requiredStreakDays: 7,
  streakShopCoinCost: 500,
);

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  await tester.pumpWidget(_app(theme, child));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsService svc = CoinsService.instance;
  final int balance = svc.balanceNotifier.value;

  setUpAll(() async {
    await (FontLoader('Proxima Nova')
          ..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'))
          ..addFont(rootBundle.load('assets/fonts/Proxima Nova Extrabold.otf')))
        .load();
    await (FontLoader('Fraunces')..addFont(rootBundle.load('assets/fonts/Fraunces-Variable.ttf'))).load();
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    svc.streakNotifier.value = StreakStatus.empty;
    svc.balanceNotifier.value = balance;
    await getIt.reset();
  });

  testWidgets('standalone guest rewards can navigate back while tab has no back button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RewardsPage())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: RewardsTabPage()));
    await tester.pump();
    expect(find.byType(BackButton), findsNothing);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('populated rewards cards fit at 320px and text scale 1.3 (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      svc.streakNotifier.value = StreakStatus.empty.copyWith(
        count: 365,
        best: 500,
        streakDay: 7,
        active: true,
        claimedToday: true,
      );
      svc.balanceNotifier.value = 10000;

      for (final (String name, Widget child) in <(String, Widget)>[
        ('hero', const RewardsHero()),
        ('freeze card', FreezeCard(onEarnCoins: () {})),
        ('balance card', BalanceCard(onSeeUses: () {})),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(1.3)),
                child: SingleChildScrollView(child: SizedBox(width: 280, child: child)),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: name);
      }
    });

    testWidgets('rewards page fits 320px at text scale 1.3 (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'rewards-layout-${brightness.name}'
        ..loggedIn = true;
      svc.streakNotifier.value = StreakStatus.empty.copyWith(
        count: 365,
        best: 500,
        streakDay: 7,
        active: true,
        claimedToday: true,
      );
      svc.balanceNotifier.value = 10000;
      final _MockShopBloc shop = _MockShopBloc();
      whenListen(
        shop,
        const Stream<StreakShopState>.empty(),
        initialState: StreakShopState(status: StreakShopStatus.success, items: <PrismWallpaper>[_shopWallpaper()]),
      );
      getIt.registerFactory<StreakShopBloc>(() => shop);
      final CoinsTestFirestore firestore = CoinsTestFirestore()
        ..transactions = <Map<String, dynamic>>[
          for (int i = 0; i < 9; i++)
            <String, dynamic>{
              'id': 'tx-$i',
              'userId': 'rewards-layout-${brightness.name}',
              'action': 'streakFreeze',
              'delta': i.isEven ? 50 : -50,
              'createdAt': DateTime.now(),
            },
        ];
      getIt.registerSingleton<FirestoreClient>(firestore);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light ? kLightTheme : kDarkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const RewardsPage(showBack: false),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      final Finder usesLink = find.text('What you can do with them');
      await tester.scrollUntilVisible(usesLink, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(tester.getRect(usesLink).width, greaterThan(0));
      await tester.tap(usesLink);
      await tester.pumpAndSettle();
      expect(find.text('Use your coins'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Earn coins'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(find.text('Watch a video'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Unlocked at 7 days'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(find.text('Unlocked at 7 days'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Show more'), 200, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      await tester.tap(find.text('Show more'));
      await tester.pump();
      expect(find.text('Show less'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('freeze sheet tracks balance changes while open', (tester) async {
    svc.balanceNotifier.value = 20;
    await _pump(tester, ThemeData.light(), FreezeCard(onEarnCoins: () {}));
    await tester.tap(find.textContaining('Get one'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('You need 50 coins.'), findsOneWidget);
    svc.balanceNotifier.value = 100;
    await tester.pump();
    expect(find.text('Balance after: 50'), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets('hero cycle settles when reduce motion is enabled while running', (tester) async {
    svc.streakNotifier.value = StreakStatus.empty.copyWith(count: 3, streakDay: 3, active: true);
    final reduce = ValueNotifier<bool>(false);
    addTearDown(reduce.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: reduce,
          builder: (context, reduced, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: const Scaffold(body: RewardsHero()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    reduce.value = true;
    await tester.pump();
    final opacities = find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(Opacity));
    expect(opacities, findsNWidgets(3));
    for (final opacity in tester.widgetList<Opacity>(opacities)) {
      expect(opacity.opacity, 1);
    }
  });

  for (final ThemeData theme in <ThemeData>[ThemeData.light(), ThemeData.dark()]) {
    final String mode = theme.brightness.name;

    testWidgets('hero: no streak ($mode)', (tester) async {
      await _pump(tester, theme, const RewardsHero());
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Open Prism every day to build a streak.'), findsOneWidget);
      expect(find.text('Finish day 7 for a +40 week bonus'), findsOneWidget);
      expect(find.text('Day 7'), findsOneWidget);
      expect(find.textContaining('Best'), findsNothing);
    });

    testWidgets('hero: claimed streak ($mode)', (tester) async {
      svc.streakNotifier.value = StreakStatus.empty.copyWith(
        count: 12,
        best: 21,
        streakDay: 5,
        active: true,
        claimedToday: true,
      );
      await _pump(tester, theme, const RewardsHero());
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Best 21 days'), findsOneWidget);
      expect(find.textContaining('Today is done. Come back tomorrow for +'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
    });

    testWidgets('freeze card: slots and full state ($mode)', (tester) async {
      svc.streakNotifier.value = StreakStatus.empty.copyWith(freezes: 1);
      await _pump(tester, theme, FreezeCard(onEarnCoins: () {}));
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.textContaining('Get one'), findsOneWidget);

      svc.streakNotifier.value = svc.streakNotifier.value.copyWith(freezes: 2);
      await tester.pump();
      expect(find.text('Full'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('freeze card: buy sheet shows balance after ($mode)', (tester) async {
      svc.balanceNotifier.value = 240;
      await _pump(tester, theme, FreezeCard(onEarnCoins: () {}));
      await tester.tap(find.textContaining('Get one'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buy a streak freeze for 50 coins?'), findsOneWidget);
      expect(find.text('Balance after: 190'), findsOneWidget);
      expect(find.text('Buy'), findsOneWidget);
    });

    testWidgets('freeze card: not enough coins asks to earn ($mode)', (tester) async {
      svc.balanceNotifier.value = 20;
      int earned = 0;
      await _pump(tester, theme, FreezeCard(onEarnCoins: () => earned++));
      await tester.tap(find.textContaining('Get one'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('You need 50 coins.'), findsOneWidget);
      await tester.tap(find.text('Earn coins'));
      await tester.pump(const Duration(seconds: 1));
      expect(earned, 1);
    });

    testWidgets('balance card ($mode)', (tester) async {
      svc.balanceNotifier.value = 240;
      int taps = 0;
      await _pump(tester, theme, BalanceCard(onSeeUses: () => taps++));
      expect(find.text('240'), findsOneWidget);
      await tester.tap(find.text('What you can do with them'));
      expect(taps, 1);
      expect(find.text('See Pro'), findsOneWidget);
    });
  }
}
