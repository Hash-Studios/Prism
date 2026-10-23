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
  final values = <String, int>{'WALL': 8};
  bool unavailable = false;
  @override
  Future<Map<String, int>> fetch(Set<String> ids) async {
    if (unavailable) throw StateError('offline');
    return {for (final id in ids) id: values[id] ?? 0};
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
}

FeedItemEntity _item(WallpaperSource source, {String id = 'wall', int? count}) {
  final core = WallpaperCore(id: id, source: source, fullUrl: '', thumbnailUrl: '', favourites: count);
  return switch (source) {
    WallpaperSource.prism => PrismFeedItem(
      id: id,
      wallpaper: PrismWallpaper(core: core),
    ),
    WallpaperSource.wallhaven => WallhavenFeedItem(
      id: id,
      wallpaper: WallhavenWallpaper(core: core),
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
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    repository = _Favourites();
    counts = _Counts();
    cubit = FavouriteCountsCubit(counts);
    bloc = FavouriteWallsBloc(
      FetchFavouriteWallsUseCase(repository),
      ToggleFavouriteWallUseCase(repository),
      ClearFavouriteWallsUseCase(repository),
    );
    getIt.registerSingleton<FavouriteCountsCubit>(cubit);
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    bloc.add(const FavouriteWallsEvent.started(userId: ''));
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

  Future<void> pump(WidgetTester tester, FeedItemEntity item, {VoidCallback? onImageTap, double scale = 1}) async {
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
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }

  test('provider semantics preserve published totals and distinguish unknown from zero', () {
    expect(displayedFavouriteCount(WallpaperSource.prism, published: 8, saved: true), 8);
    expect(displayedFavouriteCount(WallpaperSource.wallhaven, published: 9, saved: false), 9);
    expect(displayedFavouriteCount(WallpaperSource.wallhaven, published: 9, saved: true), 9);
    expect(displayedFavouriteCount(WallpaperSource.prism, saved: true), isNull);
    expect(displayedFavouriteCount(WallpaperSource.prism, published: 0, saved: false), 0);
    expect(displayedFavouriteCount(WallpaperSource.pexels, saved: false), isNull);
    expect(displayedFavouriteCount(WallpaperSource.pexels, saved: true), 1);
    expect(displayedFavouriteCount(WallpaperSource.pexels, published: 12, saved: false), 12);
  });

  testWidgets('heart is below image, toggles without opening image, and keeps authoritative total', (tester) async {
    var opened = 0;
    await pump(tester, _item(WallpaperSource.prism), onImageTap: () => opened++);
    expect(find.text('8'), findsOneWidget);
    final heart = find.byIcon(Icons.favorite_border_rounded);
    expect(tester.getTopLeft(heart).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('image'))).dy));
    expect(find.text('depth badge'), findsOneWidget);
    await tester.tap(heart);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(opened, 0);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('image')));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(cubit.close);
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
                quickActions: true,
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
    expect(image.onLongPress, isNotNull);
    expect(
      find.descendant(of: find.byType(PrismWallTile), matching: find.byIcon(Icons.favorite_border_rounded)),
      findsNothing,
    );
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(cubit.close);
  });

  testWidgets('initial favourite does not add twice, same-length sync and account switch update heart', (tester) async {
    final item = _item(WallpaperSource.prism);
    bloc.add(FavouriteWallsEvent.synced(userId: '', items: [FavouriteWallEntity.fromFeedItem(item)]));
    await pump(tester, item);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    bloc.add(
      FavouriteWallsEvent.synced(
        userId: '',
        items: [FavouriteWallEntity.fromFeedItem(_item(WallpaperSource.prism, id: 'other'))],
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    app_state.prismUser = profileUser(id: 'different');
    bloc.add(const FavouriteWallsEvent.started(userId: 'different'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('Pexels shows no count then one then no count', (tester) async {
    await pump(tester, _item(WallpaperSource.pexels));
    expect(find.text('1'), findsNothing);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('1'), findsNothing);
  });

  testWidgets('failed membership load retains a locally saved heart', (tester) async {
    await getIt<FavoritesLocalDataSource>().setWallFavourite('', 'wall', true);
    repository.fetchFails = true;
    bloc.add(const FavouriteWallsEvent.refreshRequested());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(bloc.state.status, LoadStatus.failure);
    await pump(tester, _item(WallpaperSource.pexels));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('failed and repeated pending taps cannot change membership or total', (tester) async {
    repository.fail = true;
    repository.pending = Completer<void>();
    await pump(tester, _item(WallpaperSource.wallhaven, count: 123));
    final heart = find.byIcon(Icons.favorite_border_rounded);
    await tester.tap(heart);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(heart);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.toggles, 1);
    repository.pending!.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('unknown is omitted, known zero is visible, large text fits a narrow card', (tester) async {
    counts.unavailable = true;
    await pump(tester, _item(WallpaperSource.prism));
    expect(find.text('0'), findsNothing);
    counts.unavailable = false;
    counts.values['WALL'] = 0;
    cubit.request('wall', force: true);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('0'), findsOneWidget);
    await pump(tester, _item(WallpaperSource.wallhaven, count: 123456789), scale: 2);
    expect(tester.takeException(), isNull);
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
