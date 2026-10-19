import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/drops.dart';
import 'package:Prism/features/drops/views/widgets/drop_actions.dart';
import 'package:Prism/features/drops/views/widgets/drop_chrome.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/features/drops/views/widgets/drop_wall_tiles.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../drop_fixtures.dart';

class _MockDropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

void main() {
  late _MockDropsBloc bloc;
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(const DropsEvent.started());
    registerFallbackValue(WallpaperDetailRoute());
  });

  setUp(() {
    bloc = _MockDropsBloc();
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    when(() => bloc.close()).thenAnswer((_) async {});
    getIt.registerFactory<DropsBloc>(() => bloc);
    CoinsService.instance.balanceNotifier.value = 100;
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pump(WidgetTester tester, DropsState state, Widget page) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    whenListen(bloc, const Stream<DropsState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: StackRouterScope(controller: router, stateHash: 0, child: page),
      ),
    );
    await tester.pump();
  }

  DropsState loaded(
    DropEntity? drop, {
    Map<String, DropUnlock> unlocked = const {},
    List<DropEntity> past = const [],
  }) => DropsState(status: LoadStatus.success, now: DateTime.now(), drop: drop, unlocked: unlocked, past: past);

  final DateTime fixedNow = DateTime(2026, 10, 20, 12);

  DropEntity dropWithin(Duration left, {int collectors = 0, int priceWall = 30, int pricePack = 100}) {
    final DropEntity base = dropEntity(priceWall: priceWall, pricePack: pricePack);
    return DropEntity(
      weekKey: base.weekKey,
      title: base.title,
      startsAt: fixedNow.subtract(const Duration(days: 1)),
      endsAt: fixedNow.add(left),
      priceWall: priceWall,
      pricePack: pricePack,
      count: base.count,
      walls: base.walls,
      collectors: collectors,
    );
  }

  DropsState at(DropEntity drop, {Map<String, DropUnlock> unlocked = const {}}) =>
      DropsState(status: LoadStatus.success, now: fixedNow, drop: drop, unlocked: unlocked);

  String countdownText(WidgetTester tester) => tester
      .widget<RichText>(
        find.descendant(of: find.byKey(const ValueKey('drop.countdown')), matching: find.byType(RichText)).first,
      )
      .text
      .toPlainText()
      .replaceAll('  ', ' ');

  Widget askButton(DropsState state, DropWall wall) => BlocProvider<DropsBloc>.value(
    value: bloc,
    child: Scaffold(
      body: Builder(
        builder: (context) => TextButton(onPressed: () => askToUnlock(context, state, wall), child: const Text('ask')),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester, DropsState state, {String wallId = 'B'}) async {
    await pump(tester, state, askButton(state, state.drop!.walls.firstWhere((w) => w.id == wallId)));
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
  }

  const DropUnlock ownedA = DropUnlock(wallId: 'A', weekKey: '2026-W42', url: 'https://full.test/A.jpg');

  group('DropsPage', () {
    testWidgets('starts the bloc and shows a skeleton while loading', (tester) async {
      await pump(tester, DropsState.initial(), const DropsPage());

      verify(() => bloc.add(const DropsEvent.started())).called(1);
      expect(find.text('Weekly Drop'), findsOneWidget);
      expect(find.byType(LoadingCards), findsOneWidget);
    });

    testWidgets('shows the eyebrow, title, countdown, prices, locked and owned tiles', (tester) async {
      await pump(
        tester,
        at(dropWithin(const Duration(days: 5, hours: 3, minutes: 7)), unlocked: {'A': ownedA}),
        const DropsPage(),
      );

      expect(find.text('THE DROP · W42'), findsOneWidget);
      expect(find.text('Weekly Drop 2026-W42'), findsOneWidget);
      expect(countdownText(tester), '05d 03h 07m');
      expect(find.text('Ends in'), findsOneWidget);
      expect(find.text('A WALL'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('THE PACK'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('Pro price'), findsNothing);
      expect(find.byType(PrismWallTile), findsNWidgets(4));
      expect(find.text('Owned'), findsOneWidget);
      expect(find.byType(DropSeal), findsNWidgets(3));
      expect(find.text('01 / 04'), findsOneWidget);
      expect(find.text('04 / 04'), findsOneWidget);
      expect(find.text('Tap to preview'), findsOneWidget);
    });

    testWidgets('in the last 24 hours the countdown says Last call', (tester) async {
      await pump(tester, at(dropWithin(const Duration(hours: 5, minutes: 20))), const DropsPage());

      expect(find.text(AppLocalizationsEn().economyDropLastCallLabel), findsOneWidget);
      expect(find.text('Ends in'), findsNothing);
      expect(countdownText(tester), '05h 20m');
      final Text countdown = tester.widget<Text>(find.byKey(const ValueKey('drop.countdown')));
      expect(countdown.style!.color, DropPalette.urgent);
    });

    testWidgets('the pack shows how many coins it saves', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3))), const DropsPage());

      expect(find.text('save 20'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('collectors show with the wall count', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3), collectors: 12)), const DropsPage());

      expect(find.text('4 walls · 12 collectors'), findsOneWidget);
    });

    testWidgets('collectors hide at zero', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3))), const DropsPage());

      expect(find.text('4 walls'), findsOneWidget);
      expect(find.textContaining('collectors'), findsNothing);
    });

    testWidgets('with every wall owned the hero says Collected instead of prices', (tester) async {
      const DropUnlock b = DropUnlock(wallId: 'B', weekKey: '2026-W42', url: 'https://full.test/B.jpg');
      await pump(
        tester,
        at(
          dropWithin(const Duration(days: 3)),
          unlocked: {
            'A': ownedA,
            'B': b,
            'C': const DropUnlock(wallId: 'C', weekKey: '2026-W42', url: 'https://full.test/C.jpg'),
            'D': const DropUnlock(wallId: 'D', weekKey: '2026-W42', url: 'https://full.test/D.jpg'),
          },
        ),
        const DropsPage(),
      );

      expect(find.text('Collected · 4/4'), findsOneWidget);
      expect(find.text('THE PACK'), findsNothing);
      expect(find.text('Tap to preview'), findsNothing);
    });

    testWidgets('Pro sees half prices and the Pro price tag', (tester) async {
      app_state.prismUser.premium = true;
      await pump(tester, loaded(dropEntity()), const DropsPage());

      expect(find.text('A WALL · PRO'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('save 10'), findsOneWidget);
    });

    testWidgets('with nothing live it says the next Drop lands Monday', (tester) async {
      await pump(tester, loaded(null), const DropsPage());

      expect(find.byType(GlintState), findsOneWidget);
      expect(find.text('The next Drop lands Monday.'), findsOneWidget);
      expect(find.byType(PrismWallTile), findsNothing);
    });

    testWidgets('an ended Drop in the slot shows the empty state', (tester) async {
      await pump(tester, loaded(dropEntity(endsIn: const Duration(days: -1))), const DropsPage());

      expect(find.text('The next Drop lands Monday.'), findsOneWidget);
    });

    testWidgets('shows the vault strip and a row per past Drop that opens its page', (tester) async {
      final old = dropEntity(
        weekKey: '2026-W41',
        startedAgo: const Duration(days: 9),
        endsIn: const Duration(days: -2),
      );
      await pump(tester, loaded(null, past: <DropEntity>[old], unlocked: {'A': ownedA}), const DropsPage());

      expect(find.text('YOUR VAULT'), findsOneWidget);
      expect(find.text('PAST DROPS'), findsOneWidget);
      expect(find.text('1/4 unlocked'), findsOneWidget);
      expect(find.text('01 / 04'), findsOneWidget);

      await tester.tap(find.text('Weekly Drop 2026-W41').last);
      await tester.pump();

      final route = verify(() => router.push(captureAny())).captured.single as DropDetailRoute;
      expect(route.args!.weekKey, '2026-W41');
    });

    testWidgets('a failed load offers Try again', (tester) async {
      await pump(tester, DropsState(status: LoadStatus.failure, now: DateTime.now()), const DropsPage());

      await tester.tap(find.text('Try again'));
      await tester.pump();

      verify(() => bloc.add(const DropsEvent.refreshed())).called(1);
    });

    testWidgets('tapping an unlocked tile opens the wall with the unlock url', (tester) async {
      await pump(tester, loaded(dropEntity(), unlocked: {'A': ownedA}), const DropsPage());

      await tester.tap(find.byType(PrismWallTile).first);
      await tester.pump();

      final route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
      final entity = route.args!.entity! as PrismFeedItem;
      expect(entity.id, 'A');
      expect(entity.fullUrl, 'https://full.test/A.jpg');
      expect(entity.thumbnailUrl, 'https://example.test/A.jpg');
    });

    testWidgets('tapping a locked tile hands the wall to the preview', (tester) async {
      DropWall? tapped;
      final DropEntity drop = dropEntity();
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                DropWallGrid(drop: drop, unlocked: const {}, canBuy: true, onLockedTap: (wall) => tapped = wall),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PrismWallTile).at(1));

      expect(tapped?.id, 'B');
    });

    testWidgets('a tile that goes from locked to owned thaws its frost in 600 ms', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      Widget tile({required bool unlocked}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 260,
            child: DropWallTile(
              wall: dropWall('A'),
              serial: '01 / 04',
              unlocked: unlocked,
              missed: false,
              busy: false,
              onTap: null,
            ),
          ),
        ),
      );
      await tester.pumpWidget(tile(unlocked: false));
      expect(find.byType(DropSeal), findsOneWidget);
      expect(find.text('Owned'), findsNothing);

      await tester.pumpWidget(tile(unlocked: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(DropSeal), findsNothing);
      expect(find.text('Owned'), findsOneWidget);
    });
  });

  group('unlock sheet', () {
    testWidgets('shows the balance and unlocking a wall sends its id', (tester) async {
      await openSheet(tester, loaded(dropEntity()));

      expect(find.text('Unlock this wall for 30'), findsOneWidget);
      expect(find.text('Unlock the pack for 100'), findsOneWidget);
      expect(find.text('You have 100 coins'), findsOneWidget);
      expect(find.text('02 / 04'), findsOneWidget);
      expect(find.textContaining('Watch a video'), findsNothing);
      expect(find.text('Earn coins'), findsNothing);

      await tester.tap(find.text('Unlock this wall for 30'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const DropsEvent.unlockRequested(wallId: 'B'))).called(1);
    });

    testWidgets('the pack button sends no wall id', (tester) async {
      await openSheet(tester, loaded(dropEntity()), wallId: 'A');
      await tester.tap(find.text('Unlock the pack for 100'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const DropsEvent.unlockRequested())).called(1);
    });

    testWidgets('with too few coins it offers a video and Earn coins', (tester) async {
      CoinsService.instance.balanceNotifier.value = 5;
      await openSheet(tester, loaded(dropEntity()), wallId: 'A');

      expect(find.textContaining('Watch a video (+'), findsOneWidget);
      expect(find.text('Earn coins'), findsOneWidget);
    });

    testWidgets('with one wall left it has no pack button', (tester) async {
      await openSheet(tester, loaded(dropEntity(wallIds: <String>['A', 'B']), unlocked: {'A': ownedA}));

      expect(find.text('Unlock this wall for 30'), findsOneWidget);
      expect(find.textContaining('Unlock the pack'), findsNothing);
    });
  });

  group('DropDetailPage', () {
    final ended = dropEntity(
      weekKey: '2026-W41',
      startedAgo: const Duration(days: 9),
      endsIn: const Duration(days: -2),
    );

    testWidgets('loads the Drop by week key', (tester) async {
      await pump(tester, DropsState.initial(), const DropDetailPage(weekKey: '2026-W41'));

      verify(() => bloc.add(const DropsEvent.started(weekKey: '2026-W41'))).called(1);
    });

    testWidgets('a locked wall of an ended Drop says Missed and does nothing on tap', (tester) async {
      await pump(tester, loaded(ended, unlocked: {'A': ownedA}), const DropDetailPage(weekKey: '2026-W41'));

      expect(find.text('This Drop has ended'), findsOneWidget);
      expect(find.text('Missed'), findsNWidgets(3));
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Collected · 1/4'), findsOneWidget);
      expect(find.text('THE PACK'), findsNothing);
      expect(find.text('Tap to preview'), findsNothing);

      await tester.tap(find.byType(PrismWallTile).at(2));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unlock this wall'), findsNothing);
    });

    testWidgets('a missing Drop says so', (tester) async {
      await pump(tester, loaded(null), const DropDetailPage(weekKey: '2026-W01'));

      expect(find.text('This Drop is gone'), findsOneWidget);
    });
  });

  group('DropCard', () {
    testWidgets('shows the title, the countdown and the unlocked count, and opens the Drops page', (tester) async {
      await pump(
        tester,
        loaded(dropEntity(), unlocked: {'A': ownedA}),
        BlocProvider<DropsBloc>.value(
          value: bloc,
          child: const Scaffold(body: DropCardView()),
        ),
      );

      expect(find.text('Weekly Drop 2026-W42'), findsOneWidget);
      expect(find.text('THE DROP · W42'), findsOneWidget);
      expect(find.text('Ends in'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economyDropCollected(1, 4)), findsOneWidget);

      await tester.tap(find.text('Preview'));
      await tester.pump();

      verify(() => router.push(any(that: isA<DropsRoute>()))).called(1);
    });

    testWidgets('says Last call when the Drop ends within a day', (tester) async {
      await pump(
        tester,
        at(dropWithin(const Duration(hours: 2, minutes: 5))),
        BlocProvider<DropsBloc>.value(
          value: bloc,
          child: const Scaffold(body: DropCardView()),
        ),
      );

      expect(find.text('Last call'), findsOneWidget);
      expect(countdownText(tester), '02h 05m');
    });

    testWidgets('is empty when no Drop is live', (tester) async {
      await pump(
        tester,
        loaded(null),
        BlocProvider<DropsBloc>.value(
          value: bloc,
          child: const Scaffold(body: DropCardView()),
        ),
      );

      expect(find.text('Preview'), findsNothing);
    });
  });
}
