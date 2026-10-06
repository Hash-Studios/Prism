import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import 'support/fav_fixtures.dart';

class _MockFetchFavouriteWallsUseCase extends Mock implements FetchFavouriteWallsUseCase {}

class _MockToggleFavouriteWallUseCase extends Mock implements ToggleFavouriteWallUseCase {}

class _MockClearFavouriteWallsUseCase extends Mock implements ClearFavouriteWallsUseCase {}

void main() {
  late _MockFetchFavouriteWallsUseCase fetchUseCase;
  late FavouriteWallsBloc bloc;

  /// Built inside the test body so the bloc runs on the fake-async clock the tester pumps.
  FavouriteWallsBloc createBloc() {
    bloc = FavouriteWallsBloc(fetchUseCase, _MockToggleFavouriteWallUseCase(), _MockClearFavouriteWallsUseCase());
    addTearDown(bloc.close);
    return bloc;
  }

  setUpAll(() {
    registerFallbackValue(const FetchFavouriteWallsParams(userId: 'user_1'));
  });

  setUp(() {
    fetchUseCase = _MockFetchFavouriteWallsUseCase();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpGrid(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<FavouriteWallsBloc>.value(
          value: bloc,
          child: const Scaffold(body: FavouriteGrid()),
        ),
      ),
    );
  }

  testWidgets('shows loading cards until the favourites arrive, then the empty state', (tester) async {
    final Completer<Result<List<FavouriteWallEntity>>> pending = Completer<Result<List<FavouriteWallEntity>>>();
    when(() => fetchUseCase(any())).thenAnswer((_) => pending.future);
    createBloc();

    await pumpGrid(tester);
    await tester.pump();

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.byType(GlintState), findsNothing);

    pending.complete(Result.success(const <FavouriteWallEntity>[]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('No favourites yet'), findsOneWidget);
    verify(() => fetchUseCase(any())).called(1);
  });

  testWidgets('shows the grid straight away when the favourites are already loaded', (tester) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(const <FavouriteWallEntity>[]));
    createBloc();
    bloc.add(const FavouriteWallsEvent.started(userId: 'user_1'));
    await tester.pump();
    await tester.pump();
    expect(bloc.state.status, LoadStatus.success);

    await pumpGrid(tester);

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  group('with favourites', () {
    late _MockClearFavouriteWallsUseCase clearUseCase;
    late _MockToggleFavouriteWallUseCase toggleUseCase;

    FavouriteWallsBloc createBlocWith(List<FavouriteWallEntity> items) {
      clearUseCase = _MockClearFavouriteWallsUseCase();
      toggleUseCase = _MockToggleFavouriteWallUseCase();
      registerFallbackValue(const ClearFavouriteWallsParams(userId: 'user_1', wallIds: <String>[]));
      registerFallbackValue(ToggleFavouriteWallParams(userId: 'user_1', wall: items.first, currentlyFavourited: false));
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.success(List<FavouriteWallEntity>.of(items)));
      when(() => clearUseCase(any())).thenAnswer((_) async => Result.success(true));
      when(() => toggleUseCase(any())).thenAnswer((_) async => Result.success(true));
      bloc = FavouriteWallsBloc(fetchUseCase, toggleUseCase, clearUseCase);
      addTearDown(bloc.close);
      return bloc;
    }

    Future<void> pumpLoaded(WidgetTester tester) async {
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('filter chips and search narrow the grid and clear filters restores it', (tester) async {
      createBlocWith(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace', createdAt: DateTime.utc(2025, 1, 2)),
      ]);
      await pumpLoaded(tester);
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Prism'));
      await tester.pump();
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No matching favourites'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.bySemanticsLabel('Wallpaper by Ada'), findsOneWidget);
      expect(find.bySemanticsLabel('Wallpaper by Grace'), findsOneWidget);
    });

    testWidgets('long press selects, Remove sends one batched delete and Undo restores', (tester) async {
      createBlocWith(<FavouriteWallEntity>[
        prismFav('a', author: 'Ada', createdAt: DateTime.utc(2025, 1, 3)),
        pexelsFav('b', author: 'Grace', createdAt: DateTime.utc(2025, 1, 2)),
        wallhavenFav('c', createdAt: DateTime.utc(2025)),
      ]);
      await pumpLoaded(tester);

      await tester.longPress(find.bySemanticsLabel('Wallpaper by Ada'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Wallpaper by Grace'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Remove from favourites'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final params = verify(() => clearUseCase(captureAny())).captured.single as ClearFavouriteWallsParams;
      expect(params.wallIds, <String>['a', 'b']);
      expect(bloc.state.items.map((wall) => wall.id), <String>['c']);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Removed 2 favourites'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.items.map((wall) => wall.id), <String>['a', 'b', 'c']);
    });

    testWidgets('legacy favourites explain themselves on tap and can be removed after a long press', (tester) async {
      createBlocWith(<FavouriteWallEntity>[legacyFav('old', author: 'Old Timer')]);
      await pumpLoaded(tester);

      await tester.tap(find.bySemanticsLabel('Wallpaper by Old Timer'));
      await tester.pump();
      expect(find.textContaining('older version'), findsOneWidget);

      await tester.longPress(find.bySemanticsLabel('Wallpaper by Old Timer'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove from favourites'), findsOneWidget);
    });

    testWidgets('a failed load with nothing cached shows an error with Retry', (tester) async {
      when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const ServerFailure('offline')));
      createBloc();
      await pumpGrid(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't load favourites"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(LoadingCards), findsNothing);
    });
  });
}
