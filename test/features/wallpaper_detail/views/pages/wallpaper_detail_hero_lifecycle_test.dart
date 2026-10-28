import 'dart:async';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart';
import 'package:Prism/features/prism_feed/domain/repositories/prism_wallpaper_repository.dart';
import 'package:Prism/features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/wallpaper_recommendation_repository.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/wallpaper_image_finders.dart';

class _PrismRepository extends Mock implements PrismWallpaperRepository {}

class _WallhavenRepository extends Mock implements WallhavenWallpaperRepository {}

class _PexelsRepository extends Mock implements PexelsWallpaperRepository {}

class _PaletteRepository extends Mock implements PaletteRepository {}

class _RecordViews extends Mock implements RecordPrismWallpaperViewsUsecase {}

class _SetCount extends Mock implements GetWallpaperSetCountUseCase {}

class _Recommendations implements WallpaperRecommendationRepository {
  @override
  Future<RecommendationPage> load({
    required FeedItemEntity current,
    required String sessionKey,
    RecommendationCursor? cursor,
  }) async => RecommendationPage(items: [], kind: RecommendationKind.related);

  @override
  void release(String sessionKey) {}
}

const _thumbnail = 'https://example.com/hero-thumb.jpg';
const _wallpaper = PrismWallpaper(
  core: WallpaperCore(
    id: 'hero-prism',
    source: WallpaperSource.prism,
    fullUrl: 'https://example.com/protected-original.jpg',
    thumbnailUrl: _thumbnail,
    width: 1080,
    height: 1920,
  ),
);
const _entity = PrismFeedItem(id: 'hero-prism', wallpaper: _wallpaper);

class _HeroRouter extends RootStackRouter {
  _HeroRouter(this.bloc);
  final WallpaperDetailBloc bloc;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Grid',
        builder: (_) => Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 40,
                top: 120,
                width: 100,
                height: 140,
                child: Hero(
                  tag: 'wall',
                  child: CachedNetworkImage(
                    cacheManager: PrismImageCache.instance,
                    imageUrl: _thumbnail,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    CustomRoute(
      path: '/detail',
      page: PageInfo(
        'Detail',
        builder: (_) => BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: const WallpaperDetailScreen(entity: _entity, heroTag: 'wall'),
        ),
      ),
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
  ];
}

void main() {
  setUpFavouriteCounts();

  testWidgets('canonical Prism loading preserves the destination Hero throughout its real 160ms flight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final assets = (await tester.runAsync(OfflineAssetFixture.create))!;
    assets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(SettingsLocalDataSource(InMemoryLocalStore())));
    final canonical = Completer<Result<PrismWallpaper?>>();
    final prism = _PrismRepository();
    when(() => prism.fetchCanonicalById('hero-prism')).thenAnswer((_) => canonical.future);
    final palette = _PaletteRepository();
    when(() => palette.generatePalette(any())).thenAnswer((_) async => Result.error(const NetworkFailure('palette')));
    final views = _RecordViews();
    when(() => views(any())).thenAnswer((_) async => Result.success('7'));
    final sets = _SetCount();
    when(() => sets(any())).thenAnswer((_) async => Result.success<int?>(null));
    final bloc = WallpaperDetailBloc(
      prism,
      _WallhavenRepository(),
      _PexelsRepository(),
      views,
      palette,
      sets,
      null,
      _Recommendations(),
    );
    final router = _HeroRouter(bloc);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      if (!canonical.isCompleted) canonical.complete(Result.success(_wallpaper));
      await bloc.close();
      await getIt.reset();
      await tester.runAsync(assets.dispose);
    });
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router.config(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push<void>(const PageRouteInfo<void>('Detail')));
    await tester.pump();
    await tester.pump();
    final destination = find.descendant(
      of: find.byType(WallpaperDetailScreen, skipOffstage: false),
      matching: find.byType(Hero, skipOffstage: false),
    );
    final heroState = tester.state(destination);
    expect(ModalRoute.of(tester.element(destination))!.transitionDuration, const Duration(milliseconds: 160));
    await tester.pump();
    expect(bloc.state, isA<WallpaperDetailLoading>());
    expect(tester.state(destination), same(heroState));
    expect(find.byType(WallpaperActionBar), findsNothing);
    expect(
      tester
          .widget<AbsorbPointer>(find.ancestor(of: destination, matching: find.byType(AbsorbPointer)).first)
          .absorbing,
      isTrue,
    );
    verify(() => prism.fetchCanonicalById('hero-prism')).called(1);
    verifyNever(() => palette.generatePalette(any()));
    final pendingUrls = networkImageUrls(tester);
    expect(pendingUrls, isNotEmpty);
    expect(pendingUrls.every((url) => url == _thumbnail), isTrue);

    final flyingImage = find.byElementPredicate((element) {
      final widget = element.widget;
      final ImageProvider? provider = widget is Image ? unwrapImageProvider(widget.image) : null;
      return provider is CachedNetworkImageProvider &&
          provider.url == _thumbnail &&
          element.findAncestorWidgetOfExactType<ProgressiveWallpaperImage>() != null &&
          element.findAncestorWidgetOfExactType<WallpaperDetailScreen>() == null &&
          element.findAncestorWidgetOfExactType<Hero>() == null;
    });
    Rect flyingRect() {
      // The destination child is lifted into the overlay while both Heroes show their placeholders.
      expect(flyingImage, findsOneWidget);
      final rect = tester.getRect(flyingImage);
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
      return rect;
    }

    // The flying card widens its corners from the tile's 12 toward the detail card's 20.
    double flightRadius() =>
        (tester.widget<ClipRRect>(find.ancestor(of: flyingImage, matching: find.byType(ClipRRect)).first).borderRadius
                as BorderRadius)
            .topLeft
            .x;

    await tester.pump(const Duration(milliseconds: 40));
    final before = flyingRect();
    expect(before.width, greaterThan(100));
    expect(before.width, lessThan(400));
    final beforeRadius = flightRadius();
    expect(beforeRadius, inExclusiveRange(12, 20));
    // The whole page grows with the flight while Prism confirms the wallpaper. It follows the picture's left edge,
    // top edge and width, so the placeholders start where the page's card slot ends, never below the picture.
    final pendingBefore = tester.getRect(
      find.descendant(of: find.byType(WallpaperDetailScreen), matching: find.byType(PrismSkeleton)),
    );
    expect(pendingBefore.top, closeTo(before.top + before.width * 528 / 392, 0.5));
    expect(pendingBefore.top, lessThanOrEqualTo(before.bottom + 0.5));
    expect(pendingBefore.width, closeTo(400 * before.width / 392, 0.5));
    final pixels = find.descendant(of: flyingImage, matching: find.byType(RawImage));
    bool hasDecodedImage() => tester.widgetList<RawImage>(pixels).any((image) => image.image != null);
    for (var attempt = 0; attempt < 20 && !hasDecodedImage(); attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(hasDecodedImage(), isTrue, reason: 'A decoded thumbnail must remain visible in the in-flight overlay.');
    expect(tester.getSize(pixels.first).isEmpty, isFalse);
    canonical.complete(Result.success(_wallpaper));
    await tester.pump();
    await tester.pump();
    expect(bloc.state, isA<WallpaperDetailLoaded>());
    expect(tester.state(destination), same(heroState));
    expect(find.byType(WallpaperActionBar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 40));
    final after = flyingRect();
    expect(after.width, greaterThan(before.width));
    expect(after.width, lessThan(400));
    expect(flightRadius(), inExclusiveRange(beforeRadius, 20));
    final actions = tester.getRect(find.byType(WallpaperActionBar));
    expect(actions.top, closeTo(after.top + after.width * 528 / 392, 0.5));
    expect(actions.top, lessThanOrEqualTo(after.bottom + 0.5));
    final flightFade = tester.widget<FadeTransition>(
      find.ancestor(of: flyingImage, matching: find.byType(FadeTransition)).first,
    );
    expect(flightFade.opacity.value, 1, reason: 'The flight must not fade out after canonical hydration.');
    await tester.pumpAndSettle();
    expect(tester.state(destination), same(heroState));
    expect(tester.getSize(destination), const Size(392, 528));
    expect(
      tester.widget<ClipRRect>(find.descendant(of: destination, matching: find.byType(ClipRRect)).first).borderRadius,
      const BorderRadius.all(Radius.circular(20)),
    );
    verifyNever(() => prism.fetchCanonicalByDocumentId(any()));
  });
}
