import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_wall_grid.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:Prism/features/favourite_walls/domain/usecases/favourite_walls_usecases.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

class _Counts implements FavouriteCountsRepository {
  final values = <String, PrismWallpaperStats>{'WALL': const PrismWallpaperStats(favourites: 8, views: 1234)};
  bool unavailable = false;
  int fetches = 0;
  @override
  Future<Map<String, PrismWallpaperStats>> fetch(Set<String> ids) async {
    fetches++;
    if (unavailable) throw StateError('offline');
    return {for (final id in ids) id: values[id] ?? const PrismWallpaperStats(favourites: 0, views: 0)};
  }
}

class _Favourites implements FavouriteWallsRepository {
  List<FavouriteWallEntity> items = [];
  bool fail = false;
  bool fetchFails = false;
  int toggles = 0;
  Completer<void>? pending;

  @override
  Future<Result<List<FavouriteWallEntity>>> fetchFavourites({required String userId}) async =>
      fetchFails ? Result.error(const ServerFailure('offline')) : Result.success(items);

  @override
  Future<Result<bool>> toggleFavourite({
    required String userId,
    required FavouriteWallEntity wall,
    required bool currentlyFavourited,
  }) async {
    toggles++;
    await pending?.future;
    if (fail) return Result.error(const ServerFailure('denied'));
    items = currentlyFavourited ? [] : [wall];
    return Result.success(!currentlyFavourited);
  }

  @override
  Future<Result<bool>> clearAll({required String userId, required List<String> wallIds}) async => Result.success(true);

  @override
  Future<Result<void>> setPinned({
    required String userId,
    required FavouriteWallEntity wall,
    DateTime? pinnedAt,
  }) async => Result.success(null);
}

FeedItemEntity _item(WallpaperSource source, {String id = 'wall', int? count, int? views}) {
  final core = WallpaperCore(id: id, source: source, fullUrl: '', thumbnailUrl: '', favourites: count);
  return switch (source) {
    WallpaperSource.prism => PrismFeedItem(
      id: id,
      wallpaper: PrismWallpaper(core: core),
    ),
    WallpaperSource.wallhaven => WallhavenFeedItem(
      id: id,
      wallpaper: WallhavenWallpaper(core: core, views: views),
    ),
    _ => PexelsFeedItem(
      id: id,
      wallpaper: PexelsWallpaper(core: core),
    ),
  };
}

void main() {
  late _Favourites repository;
  late _Counts counts;
  late FavouriteWallsBloc bloc;
  late FavouriteCountsCubit cubit;

  setUp(() async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
    app_state.prismUser = profileUser(id: 'user', loggedIn: true);
    repository = _Favourites();
    counts = _Counts();
    cubit = FavouriteCountsCubit(counts);
    bloc = FavouriteWallsBloc(
      FetchFavouriteWallsUseCase(repository),
      ToggleFavouriteWallUseCase(repository),
      ClearFavouriteWallsUseCase(repository),
      SetFavouritePinUseCase(repository),
    );
    getIt.registerSingleton<FavouriteCountsCubit>(cubit);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    bloc.add(const FavouriteWallsEvent.started(userId: 'user'));
    await bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    await bloc.close();
    await cubit.close();
    await getIt.reset();
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  Future<void> pump(
    WidgetTester tester,
    FeedItemEntity item, {
    VoidCallback? onImageTap,
    double scale = 1,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Center(
                child: Directionality(
                  textDirection: direction,
                  child: SizedBox(
                    width: 120,
                    height: 260,
                    child: FavouriteWallpaperCard(
                      item: item,
                      child: GestureDetector(
                        key: const ValueKey('image'),
                        onTap: onImageTap,
                        child: const ColoredBox(color: Colors.grey, child: Text('depth badge')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a tile is image only: no heart even when saved, no counts, and taps reach the image', (tester) async {
    final item = _item(WallpaperSource.prism);
    bloc.add(FavouriteWallsEvent.synced(userId: 'user', items: [FavouriteWallEntity.fromFeedItem(item)]));
    var opened = 0;
    await pump(tester, item, onImageTap: () => opened++);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.bySemanticsLabel('Unfavourite'), findsNothing);
    expect(find.text('8'), findsNothing);
    expect(counts.fetches, 0, reason: 'tiles do not fetch counts; the detail screen does');
    final image = find.byKey(const ValueKey('image'));
    expect(tester.getSize(image), const Size(120, 260), reason: 'no footer band under the image');
    expect(find.text('depth badge'), findsOneWidget);
    await tester.tap(image);
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail view totals override cached totals and render without fetched favourites', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PrismFavouriteCount(id: 'wall', views: 42)),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.bySemanticsLabel('8 favourites'), findsOneWidget);
    expect(find.bySemanticsLabel('42 views'), findsOneWidget);

    await cubit.close();
    await getIt.unregister<FavouriteCountsCubit>();
    counts.unavailable = true;
    cubit = FavouriteCountsCubit(counts);
    getIt.registerSingleton<FavouriteCountsCubit>(cubit);
    final fetchesBeforeFailure = counts.fetches;
    cubit.request('wall');
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PrismFavouriteCount(id: 'wall', views: 42)),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(counts.fetches, greaterThan(fetchesBeforeFailure));
    expect(cubit.state, isEmpty);
    expect(find.bySemanticsLabel('42 views'), findsOneWidget);
    expect(find.bySemanticsLabel('8 favourites'), findsNothing);
  });

  testWidgets('real wallpaper tile has no heart overlay and preserves image gestures, hero and badges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: SizedBox(
              width: 120,
              height: 260,
              child: WallpaperTile(
                item: _item(WallpaperSource.prism),
                index: 0,
                overlay: const Align(alignment: Alignment.topRight, child: Text('premium badge')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(Hero), findsOneWidget);
    expect(find.text('premium badge'), findsOneWidget);
    final image = tester.widget<PrismWallTile>(find.byType(PrismWallTile));
    expect(image.onTap, isNotNull);
    expect(image.onLongPress, isNull);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(cubit.close);
  });

  testWidgets('grid preserves image ratio inside a constrained parent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: Builder(
              builder: (context) => GridView.builder(
                padding: PrismWallGrid.padding,
                gridDelegate: PrismWallGrid.delegate(
                  context,
                  columns: 2,
                  aspectRatio: 0.5,
                  footerHeight: favouriteFooterHeight,
                ),
                itemCount: 1,
                itemBuilder: (_, _) => const Column(
                  children: [
                    Expanded(child: SizedBox.expand(key: ValueKey('image'))),
                    SizedBox(height: favouriteFooterHeight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byKey(const ValueKey('image')));
    expect(size.width / size.height, closeTo(0.5, 0.001));
  });
}
