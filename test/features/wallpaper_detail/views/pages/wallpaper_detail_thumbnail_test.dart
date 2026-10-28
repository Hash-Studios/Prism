import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

void main() {
  setUpFavouriteCounts();
  late _MockWallpaperDetailBloc bloc;

  setUp(() {
    bloc = _MockWallpaperDetailBloc();
    when(() => bloc.state).thenReturn(const WallpaperDetailLoading());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpDetail(WidgetTester tester, {required WallpaperDetailState state, String? thumbnailUrl}) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(
            wallId: 'wall-id',
            source: WallpaperSource.wallhaven,
            thumbnailUrl: thumbnailUrl,
          ),
        ),
      ),
    );
  }

  testWidgets('normalizes the route thumbnail in the initial state', (tester) async {
    const String crop = 'https://th.wallhaven.cc/lg/21/wall.jpg';
    await pumpDetail(tester, state: const WallpaperDetailInitial(), thumbnailUrl: crop);

    expect(networkImageUrls(tester), ['https://th.wallhaven.cc/lg/21/wall.jpg']);
  });

  testWidgets('normalizes the loading-state URL instead of the route fallback', (tester) async {
    const String crop = 'https://th.wallhaven.cc/small/21/state.jpg';
    await pumpDetail(
      tester,
      state: const WallpaperDetailLoading(thumbnailUrl: crop),
      thumbnailUrl: 'https://th.wallhaven.cc/lg/21/route.jpg',
    );

    expect(networkImageUrls(tester), ['https://th.wallhaven.cc/lg/21/state.jpg']);
  });

  testWidgets('keeps a non-Wallhaven URL unchanged', (tester) async {
    const String pexelsUrl = 'https://images.pexels.com/photos/1/tiny.jpg';
    await pumpDetail(tester, state: const WallpaperDetailLoading(thumbnailUrl: pexelsUrl));
    expect(networkImageUrls(tester), [pexelsUrl]);
  });

  testWidgets('does not build a cached image when the route thumbnail is null', (tester) async {
    await pumpDetail(tester, state: const WallpaperDetailInitial());
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('a Prism display surface never reuses the original as its thumbnail', (tester) async {
    const String original = 'https://img.test/original.jpg';

    FeedItemEntity prism(String thumb) => FeedItemEntity.prism(
      id: 'prism-wall',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(id: 'prism-wall', source: WallpaperSource.prism, fullUrl: original, thumbnailUrl: thumb),
      ),
    );

    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));

    Future<void> pumpLoaded(WidgetTester tester, FeedItemEntity entity) async {
      final WallpaperDetailLoaded loaded = WallpaperDetailLoaded(
        entity: entity,
        paletteLoading: false,
        recommendations: const RecommendationState.exhausted(),
      );
      whenListen(bloc, const Stream<WallpaperDetailState>.empty(), initialState: loaded);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(entity: entity),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpLoaded(tester, prism(original));

    expect(
      tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((image) => image.imageUrl),
      isNot(contains(original)),
    );
    expect(networkImageUrls(tester), isNot(contains(original)));
  });

  testWidgets('a wall of the day route never paints an original while its detail is loading or unavailable', (
    tester,
  ) async {
    const String original = 'https://storage.example/private-original.jpg?token=secret';
    final WallpaperDetailRoute route = wallOfTheDayRoute(
      const WallOfTheDayEntity(wallId: 'wotd-wall', url: original, thumbnailUrl: '', photographer: 'Author'),
    );
    final WallpaperDetailRouteArgs args = route.args!;

    for (final WallpaperDetailState state in <WallpaperDetailState>[
      WallpaperDetailLoading(thumbnailUrl: args.thumbnailUrl),
      const WallpaperDetailError(failure: WallpaperDetailLoadFailure.unavailable, thumbnailUrl: original),
    ]) {
      when(() => bloc.state).thenReturn(state);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<WallpaperDetailBloc>.value(
            value: bloc,
            child: WallpaperDetailScreen(wallId: args.wallId, source: args.source, thumbnailUrl: args.thumbnailUrl),
          ),
        ),
      );
      await tester.pump();

      expect(networkImageUrls(tester), isNot(contains(original)));
      expect(
        tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((image) => image.imageUrl),
        isNot(contains(original)),
      );
    }
  });

  testWidgets('a wall of the day route keeps an allowlisted Prism thumbnail while its detail loads', (tester) async {
    const String original = 'https://storage.example/private-original.jpg?token=secret';
    const String thumbnail = 'https://prismwalls.com/api/ai/assets/ai/studio/thumb_wall.jpg';
    final WallpaperDetailRoute route = wallOfTheDayRoute(
      const WallOfTheDayEntity(wallId: 'wotd-wall', url: original, thumbnailUrl: thumbnail, photographer: 'Author'),
    );
    final WallpaperDetailRouteArgs args = route.args!;
    when(() => bloc.state).thenReturn(WallpaperDetailLoading(thumbnailUrl: args.thumbnailUrl));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(wallId: args.wallId, source: args.source, thumbnailUrl: args.thumbnailUrl),
        ),
      ),
    );
    await tester.pump();

    expect(networkImageUrls(tester), contains(thumbnail));
    expect(networkImageUrls(tester), isNot(contains(original)));
  });

  testWidgets('a distinct safe Prism thumbnail and display derivative remain available', (tester) async {
    const String original = 'https://img.test/original.jpg';
    const String thumbnail = 'https://img.test/thumb.jpg';
    const FeedItemEntity entity = FeedItemEntity.prism(
      id: 'prism-wall',
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: 'prism-wall',
          source: WallpaperSource.prism,
          fullUrl: original,
          thumbnailUrl: thumbnail,
        ),
      ),
    );
    ProgressiveWallpaperImage.offlineCopyOverride = (_) async => null;
    addTearDown(() => ProgressiveWallpaperImage.offlineCopyOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressiveWallpaperImage(display: WallpaperDisplaySource.of(entity, projectId: '123')),
      ),
    );
    await tester.pump();

    final ProgressiveWallpaperImage image = tester.widget<ProgressiveWallpaperImage>(
      find.byType(ProgressiveWallpaperImage),
    );
    expect(image.display.thumbnail, thumbnail);
    expect(
      image.display.full,
      'https://us-central1-123.cloudfunctions.net/wallpaperPreview?id=prism-wall&thumb=https%3A%2F%2Fimg.test%2Fthumb.jpg',
    );
    expect(networkImageUrls(tester), contains(thumbnail));
    expect(networkImageUrls(tester), isNot(contains(original)));
  });

  testWidgets('an empty route thumbnail shows localized loading without image or Hero widgets', (tester) async {
    await pumpDetail(tester, state: const WallpaperDetailInitial(), thumbnailUrl: '');

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(WallpaperDetailScreen)));
    expect(find.text(l10n.wallpaperLoadingWallpaper), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Hero), findsNothing);
    verify(
      () => bloc.add(const LoadFromId(wallId: 'wall-id', source: WallpaperSource.wallhaven, thumbnailUrl: '')),
    ).called(1);
  });

  testWidgets('an empty loading-state thumbnail does not fall back to the route image', (tester) async {
    await pumpDetail(
      tester,
      state: const WallpaperDetailLoading(thumbnailUrl: ''),
      thumbnailUrl: 'https://th.wallhaven.cc/lg/21/route.jpg',
    );

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(WallpaperDetailScreen)));
    expect(find.text(l10n.wallpaperLoadingWallpaper), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('an empty error thumbnail shows the not-found message and retries with the same id and source', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      state: const WallpaperDetailError(failure: WallpaperDetailLoadFailure.notFound, thumbnailUrl: ''),
      thumbnailUrl: '',
    );

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(WallpaperDetailScreen)));
    expect(find.text(l10n.wallpaperOpenError), findsOneWidget);
    expect(find.text(l10n.wallpaperDetailNotFound), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Hero), findsNothing);

    await tester.tap(find.text(l10n.wallpaperTryAgain));
    await tester.pump();

    verify(
      () => bloc.add(const LoadFromId(wallId: 'wall-id', source: WallpaperSource.wallhaven, thumbnailUrl: '')),
    ).called(2);
  });
}
