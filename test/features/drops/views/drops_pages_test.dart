import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/drops.dart';
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
    addTearDown(tester.view.reset);
    whenListen(bloc, const Stream<DropsState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
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

  const DropUnlock ownedA = DropUnlock(wallId: 'A', weekKey: '2026-W42', url: 'https://full.test/A.jpg');

  group('DropsPage', () {
    testWidgets('starts the bloc and shows a skeleton while loading', (tester) async {
      await pump(tester, DropsState.initial(), const DropsPage());

      verify(() => bloc.add(const DropsEvent.started())).called(1);
      expect(find.text('Weekly Drop'), findsOneWidget);
      expect(find.byType(LoadingCards), findsOneWidget);
    });

    testWidgets('shows the countdown, prices, locked and unlocked tiles', (tester) async {
      await pump(tester, loaded(dropEntity(), unlocked: {'A': ownedA}), const DropsPage());

      expect(find.text('Weekly Drop 2026-W42'), findsOneWidget);
      expect(find.textContaining('Ends in 5d'), findsOneWidget);
      expect(find.text('30 a wall'), findsOneWidget);
      expect(find.text('Pack 90'), findsOneWidget);
      expect(find.text('Pro price'), findsNothing);
      expect(find.byType(PrismWallTile), findsNWidgets(4));
      expect(find.text('Unlocked'), findsOneWidget);
      expect(find.text('Locked'), findsNWidgets(3));
    });

    testWidgets('Pro sees half prices and the Pro price tag', (tester) async {
      app_state.prismUser.premium = true;
      await pump(tester, loaded(dropEntity()), const DropsPage());

      expect(find.text('15 a wall'), findsOneWidget);
      expect(find.text('Pack 50'), findsOneWidget);
      expect(find.text('Pro price'), findsOneWidget);
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
      expect(find.text('1/4 unlocked'), findsOneWidget);

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

    testWidgets('tapping a locked tile opens the sheet and unlocking sends the wall id', (tester) async {
      await pump(tester, loaded(dropEntity()), const DropsPage());

      await tester.tap(find.byType(PrismWallTile).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Unlock this wall for 30'), findsOneWidget);
      expect(find.text('Unlock the pack for 100'), findsOneWidget);
      expect(find.textContaining('Watch a video'), findsNothing);
      expect(find.text('Earn coins'), findsNothing);

      await tester.tap(find.text('Unlock this wall for 30'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const DropsEvent.unlockRequested(wallId: 'B'))).called(1);
    });

    testWidgets('the pack button sends no wall id', (tester) async {
      await pump(tester, loaded(dropEntity()), const DropsPage());

      await tester.tap(find.byType(PrismWallTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlock the pack for 100'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const DropsEvent.unlockRequested())).called(1);
    });

    testWidgets('with too few coins the sheet offers a video and Earn coins', (tester) async {
      CoinsService.instance.balanceNotifier.value = 5;
      await pump(tester, loaded(dropEntity()), const DropsPage());

      await tester.tap(find.byType(PrismWallTile).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Watch a video (+'), findsOneWidget);
      expect(find.text('Earn coins'), findsOneWidget);
    });

    testWidgets('with one wall left the sheet has no pack button', (tester) async {
      await pump(tester, loaded(dropEntity(wallIds: <String>['A', 'B']), unlocked: {'A': ownedA}), const DropsPage());

      await tester.tap(find.byType(PrismWallTile).last);
      await tester.pumpAndSettle();

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
      expect(find.text('Unlocked'), findsOneWidget);
      expect(find.text('30 a wall'), findsNothing);

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
      expect(find.textContaining('Ends in'), findsOneWidget);
      expect(find.text('1/4 unlocked'), findsOneWidget);

      await tester.tap(find.byType(PrismCard));
      await tester.pump();

      verify(() => router.push(any(that: isA<DropsRoute>()))).called(1);
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

      expect(find.byType(PrismCard), findsNothing);
    });
  });
}
