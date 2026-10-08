import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/data/wallpaper_search_service.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_widget.dart';
import 'package:Prism/features/user_search/views/widgets/search_grid.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchDiscoveryBloc extends MockBloc<SearchDiscoveryEvent, SearchDiscoveryState>
    implements SearchDiscoveryBloc {}

class _MockWallpaperSearchService extends Mock implements WallpaperSearchService {}

const String _cropUrl = 'https://th.wallhaven.cc/lg/21/21276x.jpg';
const String _fullUrl = 'https://wallhaven.cc/w/21276x';

WallhavenWallpaper _wall(String rawOriginal) => WallhavenWallpaper(
  core: const WallpaperCore(id: '21276x', source: WallpaperSource.wallhaven, fullUrl: _fullUrl, thumbnailUrl: _cropUrl),
  thumbs: <String, String>{'original': rawOriginal},
);

Future<void> _pumpDiscovery(WidgetTester tester, WallhavenWallpaper wall) async {
  final state = SearchDiscoveryState(status: LoadStatus.success, trendingWalls: <WallhavenWallpaper>[wall]);
  final bloc = _MockSearchDiscoveryBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, const Stream<SearchDiscoveryState>.empty(), initialState: state);
  await tester.pumpWidget(
    BlocProvider<SearchDiscoveryBloc>.value(
      value: bloc,
      child: MaterialApp(
        home: Scaffold(
          body: SearchDiscoveryWidget(tags: const <String>[], selectedTag: '', onTagPressed: (_) {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final rawOriginal in <String>['', ' ']) {
    testWidgets('discovery keeps the lg crop and ignores cached original thumb $rawOriginal', (tester) async {
      await _pumpDiscovery(tester, _wall(rawOriginal));

      expect(
        find.byWidgetPredicate((widget) => widget is CachedNetworkImage && widget.imageUrl == _cropUrl),
        findsOneWidget,
      );
    });
  }

  setUp(() async {
    if (getIt.isRegistered<WallpaperSearchService>()) {
      await getIt.unregister<WallpaperSearchService>();
    }
    getIt.registerSingleton<WallpaperSearchService>(_MockWallpaperSearchService());
  });

  tearDown(() async {
    if (getIt.isRegistered<WallpaperSearchService>()) {
      await getIt.unregister<WallpaperSearchService>();
    }
  });

  for (final rawOriginal in <String>['', ' ']) {
    testWidgets('search grid keeps the lg crop and ignores cached original thumb $rawOriginal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchGrid(
              key: ValueKey<String>(rawOriginal),
              query: 'test',
              provider: SearchProviderValue.wallhaven,
              initialResults: <FeedItemEntity>[WallhavenFeedItem(id: '21276x', wallpaper: _wall(rawOriginal))],
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((widget) => widget is CachedNetworkImage && widget.imageUrl == _cropUrl),
        findsOneWidget,
      );
    });
  }

  testWidgets('a Wallhaven small thumb is requested as lg in the grid, never the original', (tester) async {
    const String smallUrl = 'https://th.wallhaven.cc/small/21/21276x.jpg';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchGrid(
            query: 'test',
            provider: SearchProviderValue.wallhaven,
            initialResults: <FeedItemEntity>[
              WallhavenFeedItem(
                id: '21276x',
                wallpaper: WallhavenWallpaper(
                  core: WallpaperCore(
                    id: '21276x',
                    source: WallpaperSource.wallhaven,
                    fullUrl: _fullUrl,
                    thumbnailUrl: smallUrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate((widget) => widget is CachedNetworkImage && widget.imageUrl == _cropUrl),
      findsOneWidget,
    );
  });

  testWidgets('discovery cards decode at card size and offer a retry when an image fails', (tester) async {
    await _pumpDiscovery(tester, _wall(''));

    final Iterable<CachedNetworkImage> images = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(images, isNotEmpty);
    expect(images.every((image) => image.memCacheHeight != null), isTrue);
    expect(find.byType(PrismImageTile), findsWidgets);
  });
}
