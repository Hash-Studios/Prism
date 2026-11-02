import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/personalized_feed/views/widgets/paged_chip_sliver.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';

class _MockPagedFeedBloc extends MockBloc<PagedFeedEvent, PagedFeedState> implements PagedFeedBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

FeedItemEntity _wall(String id) => FeedItemEntity.prism(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://full.test/$id.jpg',
      thumbnailUrl: 'https://thumb.test/$id.jpg',
    ),
  ),
);

/// Mirrors the Home feed wiring: the column count and the decode height both come from the grid density.
class _DensityGrid extends StatelessWidget {
  const _DensityGrid({required this.bloc});

  final PagedFeedBloc bloc;

  @override
  Widget build(BuildContext context) {
    final int columns = PrismWallGrid.columns(context);
    return CustomScrollView(
      slivers: <Widget>[
        PagedChipSliver(
          bloc: bloc,
          failureTitle: 'Failed',
          emptyTitle: 'Empty',
          crossAxisCount: columns,
          tileMemCacheHeight: gridTileDecodeHeight(context, crossAxisCount: columns),
        ),
      ],
    );
  }
}

void _setSurface(WidgetTester tester, Size logical, double devicePixelRatio) {
  tester.view.physicalSize = logical * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
}

Future<int> _columnsAt(
  WidgetTester tester, {
  required Size size,
  double devicePixelRatio = 3,
  WallGridDensity? density,
}) async {
  _setSurface(tester, size, devicePixelRatio);
  int? columns;
  final Widget probe = Builder(
    builder: (context) {
      columns = PrismWallGrid.columns(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      home: density == null
          ? probe
          : LayoutPrefsScope(
              prefs: ValueNotifier<LayoutPrefs>(LayoutPrefs(density: density)),
              child: probe,
            ),
    ),
  );
  return columns!;
}

int _gridColumns(WidgetTester tester) =>
    (tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
        .crossAxisCount;

void main() {
  setUpFavouriteCounts();
  setUpAll(() {
    registerFallbackValue(const PagedFeedEvent.refreshRequested());
    registerFallbackValue(WallpaperDetailRoute());
  });
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });
  tearDown(AnalyticsRuntime.reset);

  group('column count', () {
    testWidgets('a 390 wide phone gets 3, 2 and 1 columns at compact, comfortable and large', (tester) async {
      expect(await _columnsAt(tester, size: const Size(390, 844), density: WallGridDensity.compact), 3);
      expect(await _columnsAt(tester, size: const Size(390, 844), density: WallGridDensity.comfortable), 2);
      expect(await _columnsAt(tester, size: const Size(390, 844), density: WallGridDensity.large), 1);
    });

    testWidgets('without a scope the grid reads the comfortable default of 2 columns', (tester) async {
      expect(await _columnsAt(tester, size: const Size(390, 844)), 2);
    });

    testWidgets('an iPad Air portrait (820 wide) gets 6, 4 and 2 columns', (tester) async {
      expect(
        await _columnsAt(tester, size: const Size(820, 1180), devicePixelRatio: 2, density: WallGridDensity.compact),
        6,
      );
      expect(
        await _columnsAt(
          tester,
          size: const Size(820, 1180),
          devicePixelRatio: 2,
          density: WallGridDensity.comfortable,
        ),
        4,
      );
      expect(
        await _columnsAt(tester, size: const Size(820, 1180), devicePixelRatio: 2, density: WallGridDensity.large),
        2,
      );
    });

    testWidgets('an iPad Air landscape (1180 wide) gets 8, 6 and 3 columns', (tester) async {
      expect(
        await _columnsAt(tester, size: const Size(1180, 820), devicePixelRatio: 2, density: WallGridDensity.compact),
        8,
      );
      expect(
        await _columnsAt(
          tester,
          size: const Size(1180, 820),
          devicePixelRatio: 2,
          density: WallGridDensity.comfortable,
        ),
        6,
      );
      expect(
        await _columnsAt(tester, size: const Size(1180, 820), devicePixelRatio: 2, density: WallGridDensity.large),
        3,
      );
    });
  });

  group('tile decode size and URL', () {
    for (final (WallGridDensity density, int columns, int decodeHeight) in <(WallGridDensity, int, int)>[
      (WallGridDensity.compact, 3, 780),
      (WallGridDensity.comfortable, 2, 1170),
      (WallGridDensity.large, 1, 2340),
    ]) {
      testWidgets('${density.name} decodes tiles at $decodeHeight px on a 390 wide phone at 3x', (tester) async {
        _setSurface(tester, const Size(390, 844), 3);
        final _MockPagedFeedBloc bloc = _MockPagedFeedBloc();
        when(() => bloc.state).thenReturn(
          PagedFeedState.initial().copyWith(
            status: LoadStatus.success,
            items: <FeedItemEntity>[
              for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f']) _wall(id),
            ],
            hasMore: false,
          ),
        );
        final _MockStackRouter router = _MockStackRouter();
        when(() => router.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(
          MaterialApp(
            builder: favouriteTestBuilder,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: LayoutPrefsScope(
                prefs: ValueNotifier<LayoutPrefs>(LayoutPrefs(density: density)),
                child: Scaffold(body: _DensityGrid(bloc: bloc)),
              ),
            ),
          ),
        );

        expect(_gridColumns(tester), columns);
        final List<PrismWallTile> tiles = tester.widgetList<PrismWallTile>(find.byType(PrismWallTile)).toList();
        expect(tiles, isNotEmpty);
        for (final PrismWallTile tile in tiles) {
          expect(tile.memCacheHeight, decodeHeight);
          expect(tile.url, startsWith('https://thumb.test/'));
          expect(tile.url, isNot(startsWith('https://full.test/')));
        }
        final List<PrismImageTile> images = tester.widgetList<PrismImageTile>(find.byType(PrismImageTile)).toList();
        expect(images, hasLength(tiles.length));
        for (final PrismImageTile image in images) {
          expect(image.memCacheHeight, decodeHeight);
        }
      });
    }

    testWidgets('gridTileDecodeHeight is 780, 1170 and 2340 for the three densities', (tester) async {
      _setSurface(tester, const Size(390, 844), 3);
      final List<int> heights = <int>[];
      for (final WallGridDensity density in WallGridDensity.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: LayoutPrefsScope(
              prefs: ValueNotifier<LayoutPrefs>(LayoutPrefs(density: density)),
              child: Builder(
                builder: (context) {
                  heights.add(gridTileDecodeHeight(context, crossAxisCount: PrismWallGrid.columns(context)));
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
      }
      expect(heights, <int>[780, 1170, 2340]);
    });
  });

  group('feed swipe from each density', () {
    for (final (WallGridDensity density, int columns) in <(WallGridDensity, int)>[
      (WallGridDensity.compact, 3),
      (WallGridDensity.comfortable, 2),
      (WallGridDensity.large, 1),
    ]) {
      testWidgets('${density.name} ($columns columns) opens the 6 wall feed on index 4', (tester) async {
        _setSurface(tester, const Size(390, 844), 3);
        final List<FeedItemEntity> items = <FeedItemEntity>[for (int i = 0; i < 6; i++) _wall('w$i')];
        final _MockPagedFeedBloc bloc = _MockPagedFeedBloc();
        when(
          () => bloc.state,
        ).thenReturn(PagedFeedState.initial().copyWith(status: LoadStatus.success, items: items, hasMore: false));
        final _MockStackRouter router = _MockStackRouter();
        when(() => router.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(
          MaterialApp(
            builder: favouriteTestBuilder,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: LayoutPrefsScope(
                prefs: ValueNotifier<LayoutPrefs>(LayoutPrefs(density: density)),
                child: Scaffold(body: _DensityGrid(bloc: bloc)),
              ),
            ),
          ),
        );
        expect(_gridColumns(tester), columns);

        final Finder tile4 = find.descendant(
          of: find.byKey(const ValueKey<String>('w4')),
          matching: find.byType(PrismWallTile),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey<String>('w4')),
          220,
          scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)),
        );
        await tester.ensureVisible(tile4);
        await tester.pump();
        await tester.tap(tile4);
        await tester.pump();

        final WallpaperDetailRoute route =
            verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
        final WallpaperFeed feed = route.args!.feed!;
        expect(route.args!.entity!.id, 'w4');
        expect(feed.tiles.map((tile) => tile.item.id), items.map((item) => item.id));
        expect(feed.indexOf(items[4]), 4);
      });
    }
  });

  testWidgets('a density change rebuilds the grid: comfortable 2 columns becomes large 1 column', (tester) async {
    _setSurface(tester, const Size(390, 844), 3);
    final ValueNotifier<LayoutPrefs> prefs = ValueNotifier<LayoutPrefs>(const LayoutPrefs());
    addTearDown(prefs.dispose);
    final _MockPagedFeedBloc bloc = _MockPagedFeedBloc();
    when(() => bloc.state).thenReturn(
      PagedFeedState.initial().copyWith(
        status: LoadStatus.success,
        items: <FeedItemEntity>[for (int i = 0; i < 6; i++) _wall('w$i')],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: favouriteTestBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LayoutPrefsScope(
          prefs: prefs,
          child: Scaffold(body: _DensityGrid(bloc: bloc)),
        ),
      ),
    );
    expect(_gridColumns(tester), 2);

    prefs.value = const LayoutPrefs(density: WallGridDensity.large);
    await tester.pump();

    expect(_gridColumns(tester), 1);
  });
}
