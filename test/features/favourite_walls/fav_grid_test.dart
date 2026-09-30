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
    expect(find.widgetWithText(GlintState, 'No favourites yet'), findsOneWidget);
    expect(find.text('Tap the heart on a wallpaper to keep it here.'), findsOneWidget);
    expect(find.text('Browse wallpapers'), findsOneWidget);
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
  });

  testWidgets('shows an error with a retry when the favourites fail to load', (tester) async {
    when(() => fetchUseCase(any())).thenAnswer((_) async => Result.error(const NetworkFailure('offline')));
    createBloc();

    await pumpGrid(tester);
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(GlintState, "Couldn't load your favourites"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
