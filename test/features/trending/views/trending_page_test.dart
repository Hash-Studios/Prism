import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/views/pages/trending_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

class _MockTrendingBloc extends MockBloc<TrendingEvent, TrendingState> implements TrendingBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

PrismWallpaper _wall(String id) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: 'https://example.test/$id.jpg',
    thumbnailUrl: '',
    authorName: 'Ana',
  ),
  review: true,
);

TrendingSection _section(LoadStatus status, {List<PrismWallpaper> walls = const <PrismWallpaper>[]}) => TrendingSection(
  status: status,
  walls: walls,
  failure: status == LoadStatus.failure ? const ServerFailure('x') : null,
);

void main() {
  late _MockTrendingBloc bloc;
  late _MockFavouriteWallsBloc favouritesBloc;
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(const TrendingEvent.started());
    registerFallbackValue(WallpaperDetailRoute());
  });

  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    favouritesBloc = _MockFavouriteWallsBloc();
    when(() => favouritesBloc.state).thenReturn(FavouriteWallsState.initial());
    bloc = _MockTrendingBloc();
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpPage(WidgetTester tester, TrendingState state, {Stream<TrendingState>? stream}) {
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, stream ?? const Stream<TrendingState>.empty(), initialState: state);
    return tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<TrendingBloc>.value(value: bloc),
              BlocProvider<FavouriteWallsBloc>.value(value: favouritesBloc),
            ],
            child: const TrendingPage(),
          ),
        ),
      ),
    );
  }

  TrendingState state({TrendingRange range = TrendingRange.week, TrendingSection? week, TrendingSection? allTime}) =>
      TrendingState.initial().copyWith(
        range: range,
        week: week ?? TrendingSection.initial(),
        allTime: allTime ?? TrendingSection.initial(),
      );

  testWidgets('shows both segments, with This week selected first', (tester) async {
    await pumpPage(tester, state(week: _section(LoadStatus.loading)));

    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);
    final SegmentedButton<TrendingRange> segments = tester.widget(find.byType(SegmentedButton<TrendingRange>));
    expect(segments.selected, <TrendingRange>{TrendingRange.week});
  });

  testWidgets('tapping All time asks the bloc for that range', (tester) async {
    await pumpPage(tester, state(week: _section(LoadStatus.success, walls: <PrismWallpaper>[_wall('a')])));

    await tester.tap(find.text('All time'));
    await tester.pump();

    verify(() => bloc.add(const TrendingEvent.rangeSelected(TrendingRange.allTime))).called(1);
  });

  testWidgets('shows the walls of the selected segment only', (tester) async {
    await pumpPage(
      tester,
      state(
        range: TrendingRange.allTime,
        week: _section(LoadStatus.success, walls: <PrismWallpaper>[_wall('week-wall')]),
        allTime: _section(LoadStatus.success, walls: <PrismWallpaper>[_wall('a'), _wall('b')]),
      ),
    );

    expect(find.bySemanticsLabel(RegExp('Ana')), findsNWidgets(2));
    final SegmentedButton<TrendingRange> segments = tester.widget(find.byType(SegmentedButton<TrendingRange>));
    expect(segments.selected, <TrendingRange>{TrendingRange.allTime});
  });

  testWidgets('a tap on a tile opens that wallpaper', (tester) async {
    await pumpPage(tester, state(week: _section(LoadStatus.success, walls: <PrismWallpaper>[_wall('a')])));

    await tester.tap(find.byType(WallpaperTile).first);
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    expect(route.args!.entity!.id, 'a');
  });

  testWidgets('pulling down asks the bloc for a refresh', (tester) async {
    final StreamController<TrendingState> states = StreamController<TrendingState>.broadcast(sync: true);
    addTearDown(states.close);
    final TrendingState loaded = state(week: _section(LoadStatus.success, walls: <PrismWallpaper>[_wall('a')]));
    when(() => bloc.add(any())).thenAnswer((_) => states.add(loaded));
    await pumpPage(tester, loaded, stream: states.stream);

    await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const TrendingEvent.refreshRequested())).called(1);
  });

  testWidgets('an empty list says so, and has no retry', (tester) async {
    await pumpPage(tester, state(week: _section(LoadStatus.success)));

    expect(find.text('Nothing is trending yet'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a failed first load shows the error and Try again refreshes', (tester) async {
    final StreamController<TrendingState> states = StreamController<TrendingState>.broadcast(sync: true);
    addTearDown(states.close);
    final TrendingState failed = state(week: _section(LoadStatus.failure));
    when(() => bloc.add(any())).thenAnswer((_) => states.add(failed));
    await pumpPage(tester, failed, stream: states.stream);

    expect(find.text("Couldn't load trending wallpapers"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => bloc.add(const TrendingEvent.refreshRequested())).called(1);
  });
}
