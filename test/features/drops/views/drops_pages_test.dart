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
import 'package:Prism/features/drops/views/widgets/drop_wall_tiles.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/favourite_test_scope.dart';
import '../drop_fixtures.dart';

class _MockDropsBloc extends MockBloc<DropsEvent, DropsState> implements DropsBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

void main() {
  setUpFavouriteCounts();
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
        builder: favouriteTestBuilder,
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

  /// A button that opens the unlock sheet for [wall], or for every wall left when [wall] is null.
  Widget askButton(DropsState state, DropWall? wall) => BlocProvider<DropsBloc>.value(
    value: bloc,
    child: Scaffold(
      body: Builder(
        builder: (context) => TextButton(onPressed: () => askToUnlock(context, state, wall), child: const Text('ask')),
      ),
    ),
  );

  /// Opens the sheet for wall [wallId], or for the pack when [wallId] is null.
  Future<void> openSheet(WidgetTester tester, DropsState state, {String? wallId = 'B'}) async {
    final DropWall? wall = wallId == null ? null : state.drop!.walls.firstWhere((w) => w.id == wallId);
    await pump(tester, state, askButton(state, wall));
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
  }

  const DropUnlock ownedA = DropUnlock(wallId: 'A', weekKey: '2026-W42', url: 'https://full.test/A.jpg');

  group('DropsPage', () {
    testWidgets('unlocking a grid wall keeps its tile and swaps its lock for Owned', (tester) async {
      final unlocked = ValueNotifier<Map<String, DropUnlock>>({});
      addTearDown(unlocked.dispose);
      final drop = dropWithin(const Duration(days: 3));
      await pump(
        tester,
        at(drop),
        Scaffold(
          body: ValueListenableBuilder<Map<String, DropUnlock>>(
            valueListenable: unlocked,
            builder: (context, owned, _) => CustomScrollView(
              slivers: [DropWallGrid(drop: drop, unlocked: owned, canBuy: true, onLockedTap: (_) {})],
            ),
          ),
        ),
      );
      final tile = find.byKey(const ValueKey<String>('A'));
      final originalElement = tester.element(tile);
      final locked = find.descendant(of: tile, matching: find.byKey(const ValueKey<String>('locked')));
      expect(locked, findsOneWidget);

      unlocked.value = {'A': ownedA};
      await tester.pump();

      expect(tester.element(tile), same(originalElement));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(locked, findsNothing);
      expect(find.descendant(of: tile, matching: find.text('Owned')), findsOneWidget);
    });

    testWidgets('starts the bloc and shows a skeleton while loading', (tester) async {
      await pump(tester, DropsState.initial(), const DropsPage());

      verify(() => bloc.add(const DropsEvent.started())).called(1);
      expect(find.text('Weekly Drop'), findsOneWidget);
      expect(find.byType(LoadingCards), findsOneWidget);
    });

    testWidgets('shows the title, dates, time left, collected count and a lock with the price on each locked wall', (
      tester,
    ) async {
      final DropEntity drop = dropWithin(const Duration(days: 5, hours: 3, minutes: 7));
      await pump(tester, at(drop, unlocked: {'A': ownedA}), const DropsPage());

      expect(find.text('Weekly Drop 2026-W42'), findsOneWidget);
      expect(find.text('${drop.datesLabel(AppLocalizationsEn())} · 4 walls'), findsOneWidget);
      expect(find.text('Ends in 5d 3h'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economyDropCollected(1, 4)), findsOneWidget);
      expect(find.byType(PrismWallTile), findsNWidgets(4));
      expect(find.byKey(const ValueKey('owned')), findsOneWidget);
      expect(find.text('Owned'), findsOneWidget);
      expect(find.byKey(const ValueKey('locked')), findsNWidgets(3));
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(3));
      expect(find.text('30'), findsNWidgets(3));
      expect(find.byType(DropTileBadge), findsNWidgets(4));
    });

    testWidgets('no grid wall is blurred or framed by a filter', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3)), unlocked: {'A': ownedA}), const DropsPage());

      expect(find.descendant(of: find.byType(DropWallGrid), matching: find.byType(ImageFiltered)), findsNothing);
      expect(find.descendant(of: find.byType(DropWallGrid), matching: find.byType(BackdropFilter)), findsNothing);
    });

    testWidgets('in the last 24 hours the time tag turns to the warning tone', (tester) async {
      await pump(tester, at(dropWithin(const Duration(hours: 5, minutes: 20))), const DropsPage());

      final PrismTag tag = tester.widget<PrismTag>(
        find.ancestor(of: find.text('Ends in 5h 20m'), matching: find.byType(PrismTag)),
      );
      expect(tag.tone, PrismTone.warning);
    });

    testWidgets('before the last day the time tag is neutral', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3))), const DropsPage());

      final PrismTag tag = tester.widget<PrismTag>(
        find.ancestor(of: find.textContaining('Ends in 3d'), matching: find.byType(PrismTag)),
      );
      expect(tag.tone, PrismTone.neutral);
    });

    testWidgets('the pack button shows its price and the coins it saves', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3))), const DropsPage());

      expect(find.text('Unlock all 4 for 100'), findsOneWidget);
      expect(find.text('Save 20'), findsOneWidget);
    });

    testWidgets('with one wall left the header has no unlock-all button', (tester) async {
      await pump(
        tester,
        at(
          dropWithin(const Duration(days: 3)),
          unlocked: {
            'A': ownedA,
            'B': const DropUnlock(wallId: 'B', weekKey: '2026-W42', url: 'https://full.test/B.jpg'),
            'C': const DropUnlock(wallId: 'C', weekKey: '2026-W42', url: 'https://full.test/C.jpg'),
          },
        ),
        const DropsPage(),
      );

      expect(find.textContaining('Unlock all'), findsNothing);
      expect(find.byKey(const ValueKey('locked')), findsOneWidget);
    });

    testWidgets('collectors show with the wall count', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3), collectors: 12)), const DropsPage());

      expect(find.textContaining('4 walls · 12 collectors'), findsOneWidget);
    });

    testWidgets('collectors hide at zero', (tester) async {
      await pump(tester, at(dropWithin(const Duration(days: 3))), const DropsPage());

      expect(find.textContaining('4 walls'), findsOneWidget);
      expect(find.textContaining('collectors'), findsNothing);
    });

    testWidgets('with every wall owned the header says collected and offers no unlock', (tester) async {
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

      expect(find.text('4 of 4 collected'), findsOneWidget);
      expect(find.textContaining('Unlock all'), findsNothing);
      expect(find.byKey(const ValueKey('locked')), findsNothing);
      expect(find.byKey(const ValueKey('owned')), findsNWidgets(4));
    });

    testWidgets('Pro sees half prices and the Pro price tag', (tester) async {
      app_state.prismUser.premium = true;
      await pump(tester, loaded(dropEntity()), const DropsPage());

      expect(find.text('Unlock all 4 for 50'), findsOneWidget);
      expect(find.text('Save 10'), findsOneWidget);
      expect(find.text('Pro price'), findsOneWidget);
      expect(find.text('15'), findsNWidgets(4));
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

      expect(find.text('Your vault'), findsOneWidget);
      expect(find.text('Past drops'), findsOneWidget);
      expect(find.textContaining('1/4 unlocked'), findsOneWidget);

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
          builder: favouriteTestBuilder,
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

    testWidgets('a tile that goes from locked to owned swaps its badge for Owned', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      Widget tile({required bool unlocked}) => MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 260,
            child: DropWallTile(
              wall: dropWall('A'),
              position: '1 of 4',
              price: 30,
              unlocked: unlocked,
              missed: false,
              busy: false,
              onTap: null,
            ),
          ),
        ),
      );
      await tester.pumpWidget(tile(unlocked: false));
      expect(find.byKey(const ValueKey('locked')), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Owned'), findsNothing);

      await tester.pumpWidget(tile(unlocked: true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byKey(const ValueKey('locked')), findsNothing);
      expect(find.byKey(const ValueKey('owned')), findsOneWidget);
      expect(find.text('Owned'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('unlock sheet', () {
    testWidgets('shows the balance, the wall and both buttons, and unlocking a wall sends its id', (tester) async {
      await openSheet(tester, loaded(dropEntity()));

      expect(find.text('Wall B'), findsOneWidget);
      expect(find.text('Unlock this wall for 30'), findsOneWidget);
      expect(find.text('Unlock all 4 for 100'), findsOneWidget);
      expect(find.text('You have 100 coins'), findsOneWidget);
      expect(find.textContaining('Watch a video'), findsNothing);
      expect(find.text('Earn coins'), findsNothing);

      await tester.tap(find.text('Unlock this wall for 30'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const DropsEvent.unlockRequested(wallId: 'B'))).called(1);
    });

    testWidgets('the pack sheet (no wall) shows only the unlock-all button, which sends no wall id', (tester) async {
      await openSheet(tester, loaded(dropEntity()), wallId: null);

      expect(find.textContaining('Unlock this wall'), findsNothing);
      expect(find.text('Unlock all 4 for 100'), findsOneWidget);

      await tester.tap(find.text('Unlock all 4 for 100'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const DropsEvent.unlockRequested())).called(1);
    });

    testWidgets('with too few coins it offers a video and Earn coins', (tester) async {
      CoinsService.instance.balanceNotifier.value = 5;
      await openSheet(tester, loaded(dropEntity()), wallId: 'A');

      expect(find.textContaining('Watch a video (+'), findsOneWidget);
      expect(find.text('Earn coins'), findsOneWidget);
    });

    testWidgets('with one wall left it has no unlock-all button', (tester) async {
      await openSheet(tester, loaded(dropEntity(wallIds: <String>['A', 'B']), unlocked: {'A': ownedA}));

      expect(find.text('Unlock this wall for 30'), findsOneWidget);
      expect(find.textContaining('Unlock all'), findsNothing);
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
      expect(find.text('1 of 4 collected'), findsOneWidget);
      expect(find.textContaining('Unlock all'), findsNothing);

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
    testWidgets('shows the title, the time left and the collected count, and opens the Drops page', (tester) async {
      await pump(
        tester,
        loaded(dropEntity(), unlocked: {'A': ownedA}),
        BlocProvider<DropsBloc>.value(
          value: bloc,
          child: const Scaffold(body: DropCardView()),
        ),
      );

      expect(find.text('Weekly Drop'), findsOneWidget);
      expect(find.text('Weekly Drop 2026-W42'), findsOneWidget);
      expect(find.text('Ends in 5d 23h'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().economyDropCollected(1, 4)), findsOneWidget);

      await tester.tap(find.text('Weekly Drop 2026-W42'));
      await tester.pump();

      verify(() => router.push(any(that: isA<DropsRoute>()))).called(1);
    });

    testWidgets('warns when the Drop ends within a day', (tester) async {
      await pump(
        tester,
        at(dropWithin(const Duration(hours: 2, minutes: 5))),
        BlocProvider<DropsBloc>.value(
          value: bloc,
          child: const Scaffold(body: DropCardView()),
        ),
      );

      final PrismTag tag = tester.widget<PrismTag>(
        find.ancestor(of: find.text('Ends in 2h 5m'), matching: find.byType(PrismTag)),
      );
      expect(tag.tone, PrismTone.warning);
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

      expect(find.text('Weekly Drop'), findsNothing);
    });
  });
}
