import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/views/widgets/trending_strip.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrendingBloc extends MockBloc<TrendingEvent, TrendingState> implements TrendingBloc {}

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

TrendingState _week(LoadStatus status, {List<PrismWallpaper> walls = const <PrismWallpaper>[], Failure? failure}) =>
    TrendingState.initial().copyWith(
      week: TrendingSection(status: status, walls: walls, failure: failure),
    );

void main() {
  late _MockTrendingBloc bloc;
  late _MockStackRouter router;

  setUpAll(() => registerFallbackValue(const TrendingRoute()));

  setUp(() {
    bloc = _MockTrendingBloc();
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
  });

  Future<void> pumpStrip(WidgetTester tester, TrendingState state) {
    whenListen(bloc, const Stream<TrendingState>.empty(), initialState: state);
    return tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: BlocProvider<TrendingBloc>.value(
            value: bloc,
            child: const Scaffold(body: TrendingStrip()),
          ),
        ),
      ),
    );
  }

  testWidgets('shows nothing while loading, when the list is empty, and when the load failed', (tester) async {
    for (final TrendingState state in <TrendingState>[
      _week(LoadStatus.initial),
      _week(LoadStatus.loading),
      _week(LoadStatus.success),
      _week(LoadStatus.failure, failure: const ServerFailure('offline')),
    ]) {
      await pumpStrip(tester, state);
      expect(find.text('Trending this week'), findsNothing);
      expect(find.text('See all'), findsNothing);
      expect(tester.getSize(find.byType(TrendingStrip)).height, 0);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('shows the title, See all, and a tile per wall up to 12', (tester) async {
    final List<PrismWallpaper> walls = List<PrismWallpaper>.generate(20, (i) => _wall('w$i'));
    await pumpStrip(tester, _week(LoadStatus.success, walls: walls));

    expect(find.text('Trending this week'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.byType(InkWell), findsAtLeastNWidgets(3));
    expect(find.bySemanticsLabel(RegExp('Ana')), findsAtLeastNWidgets(3));
  });

  testWidgets('See all opens the Trending page', (tester) async {
    await pumpStrip(tester, _week(LoadStatus.success, walls: <PrismWallpaper>[_wall('a')]));

    await tester.tap(find.text('See all'));
    await tester.pump();

    expect(verify(() => router.push(captureAny())).captured.single, isA<TrendingRoute>());
  });

  testWidgets('a tap on a tile opens that wallpaper without a refetch', (tester) async {
    await pumpStrip(tester, _week(LoadStatus.success, walls: <PrismWallpaper>[_wall('a'), _wall('b')]));

    await tester.tap(find.byType(PrismImageTile).at(1), warnIfMissed: false);
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    expect(route.args!.entity!.id, 'b');
  });
}
