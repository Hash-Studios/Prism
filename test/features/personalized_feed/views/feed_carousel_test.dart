import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_carousel_slide.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/repositories/startup_repository.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/theme_mode/seasonal_themes.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../drops/drop_fixtures.dart';

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockStartupRepository extends Mock implements StartupRepository {}

class _FakeTabsRouter extends ChangeNotifier implements TabsRouter {
  @override
  int get activeIndex => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StartupConfigEntity _startupConfig({required String bannerText}) => StartupConfigEntity(
  topImageLink: app_constants.defaultTopImageLink,
  bannerText: bannerText,
  bannerTextOn: true,
  bannerUrl: '',
  obsoleteAppVersion: '',
  verifiedUsers: const <String>[],
  premiumCollections: const <String>[],
  aiEnabled: true,
  aiRolloutPercent: 100,
  aiSubmitEnabled: true,
  aiVariationsEnabled: true,
  useRcPaywalls: true,
  onboardingV2Enabled: true,
);

PrismFeedItem _wall(String id, {List<String>? collections}) =>
    FeedItemEntity.prism(
          id: id,
          wallpaper: PrismWallpaper(
            core: WallpaperCore(
              id: id,
              source: WallpaperSource.prism,
              fullUrl: '',
              thumbnailUrl: '',
              authorName: 'Ana',
              category: 'Landscapes',
            ),
            collections: collections,
          ),
        )
        as PrismFeedItem;

PrismWallpaper _boosted(String id) => PrismWallpaper(
  core: WallpaperCore(
    id: id,
    source: WallpaperSource.prism,
    fullUrl: '',
    thumbnailUrl: '',
    authorName: 'Ana',
    category: 'Landscapes',
  ),
  boostedUntil: DateTime.now().add(const Duration(hours: 3)),
);

void main() {
  const Size screen = Size(400, 800);
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    seasonClock = () => DateTime(2026, 12);
  });
  tearDown(() async {
    seasonClock = DateTime.now;
    if (getIt.isRegistered<StartupRepository>()) await getIt.unregister<StartupRepository>();
    AnalyticsRuntime.reset();
  });

  /// The first page is the promo banner, then one page per wall. Reduce motion keeps autoplay off.
  Future<void> pumpCarousel(
    WidgetTester tester,
    List<PrismFeedItem> walls, {
    Size size = screen,
    EdgeInsets viewPadding = EdgeInsets.zero,
    bool useBottomBar = false,
    bool reduceMotion = true,
    List<PrismWallpaper> boosted = const <PrismWallpaper>[],
    WallOfTheDayEntity? wotdEntity,
    DropEntity? liveDrop,
    StackRouter? router,
    ThemeData? theme,
    ThemeBloc? themeBloc,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..viewPadding = FakeViewPadding(
        top: viewPadding.top,
        right: viewPadding.right,
        bottom: viewPadding.bottom,
        left: viewPadding.left,
      )
      ..padding = FakeViewPadding(
        top: viewPadding.top,
        right: viewPadding.right,
        bottom: viewPadding.bottom,
        left: viewPadding.left,
      );
    addTearDown(tester.view.reset);
    final wotd = _MockWotdBloc();
    final _FakeTabsRouter tabsRouter = _FakeTabsRouter();
    addTearDown(tabsRouter.dispose);
    when(() => wotd.state).thenReturn(
      WotdState.initial().copyWith(
        status: wotdEntity == null ? LoadStatus.initial : LoadStatus.success,
        entity: wotdEntity,
      ),
    );
    final Widget carousel = router == null
        ? FeedCarousel(previewWalls: walls, boostedWalls: boosted, liveDrop: liveDrop)
        : StackRouterScope(
            controller: router,
            stateHash: 0,
            child: FeedCarousel(previewWalls: walls, boostedWalls: boosted, liveDrop: liveDrop),
          );
    Widget carouselWithBloc = BlocProvider<WotdBloc>.value(value: wotd, child: carousel);
    if (themeBloc != null) {
      carouselWithBloc = BlocProvider<ThemeBloc>.value(value: themeBloc, child: carouselWithBloc);
    }
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: TabsRouterScope(
          controller: tabsRouter,
          stateHash: 0,
          child: Scaffold(
            body: useBottomBar
                ? BottomBar(child: carouselWithBloc)
                : Align(alignment: Alignment.topCenter, child: carouselWithBloc),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> swipeToNextPage(WidgetTester tester) async {
    await tester.fling(find.byType(CarouselSlider), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
  }

  testWidgets('a page is the screen less a 4 px margin each side, 0.6 times as tall, with rounded corners', (
    tester,
  ) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);

    final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
    expect(card.left, 4);
    expect(card.width, 392);
    expect(card.height, closeTo(235.2, 0.01));
    final ClipRRect clip = tester.widget<ClipRRect>(
      find.descendant(of: find.byType(FeedHeroCard), matching: find.byType(ClipRRect)).first,
    );
    expect(clip.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('the Duo landscape carousel and its dots use the tab body width beside the rail', (tester) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a'), _wall('b')],
      size: const Size(951, 669),
      viewPadding: const EdgeInsets.only(right: 84, bottom: 34),
      useBottomBar: true,
    );

    final Rect carousel = tester.getRect(find.byType(FeedCarousel));
    final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
    final Rect secondCard = tester.getRect(find.byType(FeedHeroCard).at(1));
    final Rect dots = tester.getRect(find.byType(FeedCarouselDots));
    expect(carousel.width, 951 - 84);
    expect(carousel.height, closeTo(((951 - 84) / 2 - 8) * 0.6, 0.01));
    expect(card.width, closeTo(carousel.width / 2 - 8, 0.01));
    expect(secondCard.left, closeTo(card.right + 8, 0.01));
    expect(secondCard.right, lessThanOrEqualTo(carousel.right));
    expect(dots.width, closeTo(carousel.width / 2, 0.01));
    expect(dots.center.dx, closeTo(card.center.dx, 0.01));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the folded Duo portrait keeps one card inside the narrowed tab body', (tester) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a'), _wall('b')],
      size: const Size(466, 678),
      viewPadding: const EdgeInsets.only(right: 84, bottom: 34),
      useBottomBar: true,
    );

    final Rect carousel = tester.getRect(find.byType(FeedCarousel));
    final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
    final Rect dots = tester.getRect(find.byType(FeedCarouselDots));
    expect(carousel.width, 466 - 84);
    expect(card.width, closeTo(carousel.width - 8, 0.01));
    expect(dots.center.dx, closeTo(card.center.dx, 0.01));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a same-size Duo rail transition rebuilds carousel layout without replacing its state', (tester) async {
    const Size size = Size(951, 669);
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a'), _wall('b')],
      size: size,
      viewPadding: const EdgeInsets.only(right: 84, bottom: 34),
      useBottomBar: true,
    );
    final State before = tester.state(find.byType(FeedCarousel));
    final Rect railCarousel = tester.getRect(find.byType(FeedCarousel));
    final Rect railDots = tester.getRect(find.byType(FeedCarouselDots));
    final double railCardHeight = railCarousel.height;
    expect(railCarousel.width, size.width - 84);
    expect(railCardHeight, closeTo(((size.width - 84) / 2 - 8) * 0.6, 0.01));
    expect(railDots.width, closeTo(railCarousel.width / 2, 0.01));
    expect(railDots.center.dx, closeTo(railCarousel.width / 4, 0.01));

    tester.view
      ..viewPadding = const FakeViewPadding(right: 100, bottom: 34)
      ..padding = const FakeViewPadding(right: 100, bottom: 34);
    await tester.pump();

    expect(tester.state(find.byType(FeedCarousel)), same(before));
    final Rect widerRailCarousel = tester.getRect(find.byType(FeedCarousel));
    final Rect widerRailCard = tester.getRect(find.byType(FeedHeroCard).first);
    final Rect widerRailSecondCard = tester.getRect(find.byType(FeedHeroCard).at(1));
    final Rect widerRailDots = tester.getRect(find.byType(FeedCarouselDots));
    expect(widerRailCarousel.width, size.width - 100);
    expect(widerRailCarousel.height, closeTo(((size.width - 100) / 2 - 8) * 0.6, 0.01));
    expect(widerRailCard.width, closeTo(widerRailCarousel.width / 2 - 8, 0.01));
    expect(widerRailSecondCard.left, closeTo(widerRailCard.right + 8, 0.01));
    expect(widerRailSecondCard.right, lessThanOrEqualTo(widerRailCarousel.right));
    expect(widerRailDots.width, closeTo(widerRailCarousel.width / 2, 0.01));
    expect(widerRailDots.center.dx, closeTo(widerRailCard.center.dx, 0.01));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the Duo carousel follows folded portrait, inner portrait, landscape, and folded metrics', (
    tester,
  ) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a'), _wall('b')],
      size: const Size(466, 678),
      viewPadding: const EdgeInsets.only(right: 84, bottom: 34),
      useBottomBar: true,
    );

    void expectLayout({required double width, required double cardWidth}) {
      final Rect carousel = tester.getRect(find.byType(FeedCarousel));
      final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
      final Rect dots = tester.getRect(find.byType(FeedCarouselDots));
      expect(carousel.width, width);
      expect(card.width, closeTo(cardWidth, 0.01));
      expect(dots.center.dx, closeTo(card.center.dx, 0.01));
    }

    expectLayout(width: 466 - 84, cardWidth: 466 - 84 - 8);

    tester.view
      ..physicalSize = const Size(669, 951)
      ..viewPadding = const FakeViewPadding(top: 82, bottom: 34)
      ..padding = const FakeViewPadding(top: 82, bottom: 34);
    await tester.pump();
    expectLayout(width: 669, cardWidth: 669 - 8);

    tester.view
      ..physicalSize = const Size(951, 669)
      ..viewPadding = const FakeViewPadding(right: 84, bottom: 34)
      ..padding = const FakeViewPadding(right: 84, bottom: 34);
    await tester.pump();
    expectLayout(width: 951 - 84, cardWidth: (951 - 84) / 2 - 8);

    tester.view
      ..physicalSize = const Size(466, 678)
      ..viewPadding = const FakeViewPadding(right: 84, bottom: 34)
      ..padding = const FakeViewPadding(right: 84, bottom: 34);
    await tester.pump();
    expectLayout(width: 466 - 84, cardWidth: 466 - 84 - 8);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('ordinary iPhone landscape does not become a side-rail carousel', (tester) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a'), _wall('b')],
      size: const Size(844, 390),
      viewPadding: const EdgeInsets.only(left: 44, right: 44),
      useBottomBar: true,
    );

    final Rect carousel = tester.getRect(find.byType(FeedCarousel));
    final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
    expect(carousel.width, 844);
    expect(card.width, closeTo(carousel.width - 8, 0.01));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iPad split, Stage Manager, and full-window widths keep the regular column policy', (tester) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a'), _wall('b')],
      size: const Size(507, 1366),
      viewPadding: const EdgeInsets.only(top: 24, right: 16),
      useBottomBar: true,
    );

    final Rect carousel = tester.getRect(find.byType(FeedCarousel));
    final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
    expect(carousel.width, 507);
    expect(card.width, closeTo(carousel.width - 8, 0.01));

    tester.view.physicalSize = const Size(700, 900);
    await tester.pump();
    final Rect stageManagerSplitCarousel = tester.getRect(find.byType(FeedCarousel));
    final Rect stageManagerSplitCard = tester.getRect(find.byType(FeedHeroCard).first);
    expect(stageManagerSplitCarousel.width, 700);
    expect(stageManagerSplitCard.width, closeTo(stageManagerSplitCarousel.width - 8, 0.01));

    tester.view.physicalSize = const Size(1032, 744);
    await tester.pump();
    final Rect stageManagerCarousel = tester.getRect(find.byType(FeedCarousel));
    final Rect stageManagerCard = tester.getRect(find.byType(FeedHeroCard).first);
    final Rect stageManagerDots = tester.getRect(find.byType(FeedCarouselDots));
    expect(stageManagerCarousel.width, 1032);
    expect(stageManagerCard.width, closeTo(stageManagerCarousel.width / 2 - 8, 0.01));
    expect(stageManagerDots.center.dx, closeTo(stageManagerCard.center.dx, 0.01));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android ignores a Duo-shaped right inset in the rendered carousel', (tester) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a'), _wall('b')],
      size: const Size(951, 669),
      viewPadding: const EdgeInsets.only(right: 84, bottom: 34),
      useBottomBar: true,
    );

    final Rect carousel = tester.getRect(find.byType(FeedCarousel));
    final Rect card = tester.getRect(find.byType(FeedHeroCard).first);
    expect(carousel.width, 951);
    expect(card.width, closeTo(carousel.width - 8, 0.01));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the banner page uses localized default copy when Remote Config has no title', (tester) async {
    final _MockStartupRepository repository = _MockStartupRepository();
    when(() => repository.currentConfig).thenReturn(_startupConfig(bannerText: ''));
    getIt.registerSingleton<StartupRepository>(repository);

    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);

    expect(find.text('Join our Telegram'), findsOneWidget);
  });

  testWidgets('the banner page preserves admin-authored Remote Config copy', (tester) async {
    final _MockStartupRepository repository = _MockStartupRepository();
    when(() => repository.currentConfig).thenReturn(_startupConfig(bannerText: 'Summer wallpaper event'));
    getIt.registerSingleton<StartupRepository>(repository);

    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);

    expect(find.text('Summer wallpaper event'), findsOneWidget);
  });

  testWidgets('a wallpaper page shows no category and no author', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);

    await swipeToNextPage(tester);

    expect(find.text('Join our Telegram'), findsNothing);
    expect(find.text('Landscapes'), findsNothing);
    expect(find.text('by Ana'), findsNothing);
    expect(find.byType(FeedHeroCard), findsOneWidget);
  });

  String shownWallId(WidgetTester tester) =>
      tester.widget<WallpaperImpression>(find.byType(WallpaperImpression)).itemId;

  List<String> shownWallIds(WidgetTester tester) => find
      .byType(WallpaperImpression)
      .evaluate()
      .map((element) => (element.widget as WallpaperImpression).itemId)
      .toList();

  testWidgets('the Wall of the Day leads, then the boosted walls with a Boosted tag and no caption, then the banner', (
    tester,
  ) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a')],
      boosted: <PrismWallpaper>[_boosted('hot1'), _boosted('hot2')],
      wotdEntity: const WallOfTheDayEntity(wallId: 'wotd-1', url: '', thumbnailUrl: '', photographer: 'Ana'),
    );

    expect(find.text('Wall of the day'), findsOneWidget);
    expect(find.byType(WallpaperImpression), findsNothing);
    expect(find.text('Boosted'), findsNothing);

    await swipeToNextPage(tester);

    expect(shownWallId(tester), 'hot1');
    expect(find.text('Boosted'), findsOneWidget);
    expect(find.text('by Ana'), findsNothing);
    expect(find.text('Landscapes'), findsNothing);

    await swipeToNextPage(tester);

    expect(shownWallId(tester), 'hot2');
    expect(find.text('Boosted'), findsOneWidget);

    await swipeToNextPage(tester);

    expect(find.text('Join our Telegram'), findsOneWidget);
    expect(find.text('Boosted'), findsNothing);

    await swipeToNextPage(tester);

    expect(shownWallId(tester), 'a');
    expect(find.text('Boosted'), findsNothing);
  });

  testWidgets('with no Wall of the Day the first boosted wall is the first page', (tester) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a')],
      boosted: <PrismWallpaper>[_boosted('hot1'), _boosted('hot2')],
    );

    expect(find.text('Wall of the day'), findsNothing);
    expect(shownWallId(tester), 'hot1');
    expect(find.text('Boosted'), findsOneWidget);
    expect(find.text('by Ana'), findsNothing);
    expect(find.text('Landscapes'), findsNothing);

    await swipeToNextPage(tester);

    expect(shownWallId(tester), 'hot2');
    expect(find.text('Boosted'), findsOneWidget);

    await swipeToNextPage(tester);

    expect(find.text('Join our Telegram'), findsOneWidget);
  });

  testWidgets('tapping a boosted page opens its wallpaper and reports the boosted carousel as the source', (
    tester,
  ) async {
    registerFallbackValue(WallpaperDetailRoute());
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    await pumpCarousel(tester, const <PrismFeedItem>[], boosted: <PrismWallpaper>[_boosted('hot1')], router: router);

    await tester.tap(find.byType(FeedHeroCard));
    await tester.pump();

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    final PrismFeedItem opened = route.args!.entity! as PrismFeedItem;
    expect(opened.id, 'hot1');
    expect(opened.wallpaper.core.authorName, 'Ana');
    final SurfaceActionTappedEvent event = analytics.events.whereType<SurfaceActionTappedEvent>().single;
    expect(event.sourceContext, 'personalized_feed_carousel_boosted');
    expect(event.itemId, 'hot1');
    expect(event.index, 0);
  });

  testWidgets('a preview page keeps the plain carousel as its tap source', (tester) async {
    registerFallbackValue(WallpaperDetailRoute());
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], router: router);
    await swipeToNextPage(tester);

    await tester.tap(find.byType(FeedHeroCard));
    await tester.pump();

    final SurfaceActionTappedEvent event = analytics.events.whereType<SurfaceActionTappedEvent>().single;
    expect(event.sourceContext, 'personalized_feed_carousel');
    expect(event.itemId, 'a');
  });

  testWidgets('looping three-column copies have distinct hero tags and fly to the tapped detail', (tester) async {
    registerFallbackValue(WallpaperDetailRoute());
    final _MockStackRouter router = _MockStackRouter();
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    when(() => router.push(any())).thenAnswer((invocation) {
      final WallpaperDetailRoute route = invocation.positionalArguments.single as WallpaperDetailRoute;
      return navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => Scaffold(
            body: Center(
              child: Hero(tag: route.args!.heroTag!, child: const Text('detail')),
            ),
          ),
        ),
      );
    });

    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('loop-wall')],
      size: const Size(1500, 900),
      reduceMotion: false,
      router: router,
      navigatorKey: navigatorKey,
    );
    await swipeToNextPage(tester);

    final List<Hero> heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
    expect(heroes, hasLength(2));
    final List<Object> tags = heroes.map((hero) => hero.tag).toList();
    expect(tags.toSet(), hasLength(2));
    expect(find.byType(FeedHeroCard), findsNWidgets(3));

    final Rect tappedCopy = tester.getRect(find.byWidget(heroes.first));
    await tester.tapAt(tappedCopy.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('detail'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final WallpaperDetailRoute route = verify(() => router.push(captureAny())).captured.single as WallpaperDetailRoute;
    expect(route.args!.heroTag, heroes.first.tag);
  });

  testWidgets('a premium wallpaper page keeps the star badge', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[
      _wall('a', collections: <String>['space']),
    ]);

    await swipeToNextPage(tester);

    expect(find.byType(PremiumStarBadge), findsOneWidget);
  });

  testWidgets('the dots sit inside the image at the bottom centre', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);

    final Rect carousel = tester.getRect(find.byType(CarouselSlider));
    final Rect dots = tester.getRect(find.byType(FeedCarouselDots));
    expect(dots.left, greaterThanOrEqualTo(carousel.left));
    expect(dots.right, lessThanOrEqualTo(carousel.right));
    expect(dots.top, greaterThanOrEqualTo(carousel.top));
    expect(dots.center.dx, closeTo(carousel.center.dx, 0.01));
    expect(carousel.bottom - dots.bottom, greaterThan(0));
    expect(carousel.bottom - dots.bottom, lessThan(16));
  });

  testWidgets('a tablet shows two unpadded half-width cards and keeps the selected page after resizing', (
    tester,
  ) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);
    await swipeToNextPage(tester);
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).current, 1);
    expect(shownWallId(tester), 'a');

    tester.view.physicalSize = const Size(960, 744);
    await tester.pump();
    await tester.pumpAndSettle();

    final CarouselSlider slider = tester.widget<CarouselSlider>(find.byType(CarouselSlider));
    expect(slider.options.viewportFraction, 0.5);
    expect(slider.options.padEnds, isFalse);
    expect(slider.options.enableInfiniteScroll, isTrue);
    expect(slider.itemCount, 3);
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).current, 1);
    expect(tester.getRect(find.byType(FeedHeroCard).first).width, 472);
    expect(shownWallIds(tester), <String>['a', 'b']);
  });

  testWidgets('autoplay is gated by page count and motion, and tablet dots track the leading card', (tester) async {
    const Size tablet = Size(1032, 744);
    await pumpCarousel(tester, const <PrismFeedItem>[], size: tablet, reduceMotion: false);
    CarouselSlider slider = tester.widget<CarouselSlider>(find.byType(CarouselSlider));
    expect(slider.itemCount, 1);
    expect(slider.options.enableInfiniteScroll, isFalse);
    expect(slider.options.autoPlay, isFalse);
    expect(find.byType(FeedCarouselDots), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(FeedCarouselDots), findsNothing);

    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], size: tablet);
    slider = tester.widget<CarouselSlider>(find.byType(CarouselSlider));
    expect(slider.itemCount, 2);
    expect(slider.options.enableInfiniteScroll, isTrue);
    expect(slider.options.autoPlay, isFalse);
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).count, 2);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).current, 0);

    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], size: tablet, reduceMotion: false);
    slider = tester.widget<CarouselSlider>(find.byType(CarouselSlider));
    expect(slider.options.autoPlay, isTrue);
    expect(tester.getRect(find.byType(FeedCarouselDots)).center.dx, 258);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).current, 1);
    expect(shownWallId(tester), 'a');
    expect(tester.getRect(find.byType(WallpaperImpression)).left, 4);
    expect(tester.getRect(find.byType(FeedCarouselDots)).center.dx, 258);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).current, 0);
    expect(tester.getRect(find.byType(FeedHeroCard).first).left, 4);
  });

  testWidgets('a single page has no dots', (tester) async {
    await pumpCarousel(tester, const <PrismFeedItem>[]);

    expect(find.byType(FeedCarouselDots), findsNothing);
  });

  const WallOfTheDayEntity wotd = WallOfTheDayEntity(wallId: 'wotd-1', url: '', thumbnailUrl: '', photographer: 'Ana');

  testWidgets('a live Drop gets the page right after the Wall of the Day, before the boosted walls', (tester) async {
    await pumpCarousel(
      tester,
      <PrismFeedItem>[_wall('a')],
      boosted: <PrismWallpaper>[_boosted('hot1')],
      wotdEntity: wotd,
      liveDrop: dropEntity(),
    );

    expect(find.text('Wall of the day'), findsOneWidget);
    expect(find.byType(DropCarouselSlide), findsNothing);

    await swipeToNextPage(tester);

    expect(find.text('THE DROP'), findsOneWidget);
    expect(find.text('Weekly Drop 2026-W42'), findsOneWidget);
    expect(find.text('4 walls · Ends in 5d 23h'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Last call'), findsNothing);
    expect(find.byType(WallpaperImpression), findsNothing);

    await swipeToNextPage(tester);

    expect(shownWallId(tester), 'hot1');
  });

  testWidgets('with no Wall of the Day the Drop is the first page', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], liveDrop: dropEntity());

    expect(find.byType(DropCarouselSlide), findsOneWidget);
  });

  testWidgets('with no live Drop the carousel has no Drop page', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], wotdEntity: wotd);

    expect(tester.widget<CarouselSlider>(find.byType(CarouselSlider)).itemCount, 3);
    await swipeToNextPage(tester);
    await swipeToNextPage(tester);
    await swipeToNextPage(tester);
    expect(find.byType(DropCarouselSlide), findsNothing);
  });

  testWidgets('an ended Drop adds no page', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], liveDrop: dropEntity(endsIn: const Duration(minutes: -5)));

    expect(find.byType(DropCarouselSlide), findsNothing);
  });

  testWidgets('the Drop page goes when the Drop ends', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], liveDrop: dropEntity(endsIn: const Duration(seconds: 1)));

    expect(find.byType(DropCarouselSlide), findsOneWidget);
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).count, 3);

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byType(DropCarouselSlide), findsNothing);
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).count, 2);
  });

  testWidgets('a Drop ending keeps the viewed wallpaper selected', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], liveDrop: dropEntity(endsIn: const Duration(seconds: 1)));
    await swipeToNextPage(tester);
    await swipeToNextPage(tester);
    expect(shownWallId(tester), 'a');

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(shownWallId(tester), 'a');
  });

  testWidgets('the last day of a Drop shows Last call', (tester) async {
    await pumpCarousel(tester, const <PrismFeedItem>[], liveDrop: dropEntity(endsIn: const Duration(hours: 5)));

    expect(find.text('Last call'), findsOneWidget);
    expect(find.text('4 walls · Ends in 4h 59m'), findsOneWidget);
  });

  testWidgets('tapping the Drop page opens the Drops route', (tester) async {
    registerFallbackValue(const DropsRoute());
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    await pumpCarousel(tester, const <PrismFeedItem>[], liveDrop: dropEntity(), router: router);

    await tester.tap(find.byType(DropCarouselSlide));
    await tester.pump();

    verify(() => router.push(any(that: isA<DropsRoute>()))).called(1);
  });

  testWidgets('a Drop that arrives later keeps the user on the page they were viewing', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')], wotdEntity: wotd);
    await swipeToNextPage(tester);
    await swipeToNextPage(tester);
    expect(shownWallId(tester), 'a');

    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')], wotdEntity: wotd, liveDrop: dropEntity());
    await tester.pumpAndSettle();

    expect(shownWallId(tester), 'a');
    expect(tester.widget<CarouselSlider>(find.byType(CarouselSlider)).itemCount, 5);
    expect(tester.widget<FeedCarouselDots>(find.byType(FeedCarouselDots)).current, 3);
  });

  group('Spooky theme card', () {
    testWidgets('shows the card in the season when the theme is not Spooky', (tester) async {
      seasonClock = () => DateTime(2026, 10, 31);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);
      await swipeToNextPage(tester);

      expect(find.text('The Spooky theme is here'), findsOneWidget);
    });

    testWidgets('hides the card once the season has ended', (tester) async {
      seasonClock = () => DateTime(2026, 11, 3);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);

      expect(find.text('The Spooky theme is here'), findsNothing);
    });

    testWidgets('keeps the viewed wallpaper selected when the seasonal card disappears', (tester) async {
      seasonClock = () => DateTime(2026, 10, 31);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);
      await swipeToNextPage(tester);
      await swipeToNextPage(tester);
      await swipeToNextPage(tester);
      expect(shownWallId(tester), 'a');

      seasonClock = () => DateTime(2026, 11, 3);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);

      expect(shownWallId(tester), 'a');
    });

    testWidgets('removes the card at the season deadline without another parent rebuild', (tester) async {
      Duration elapsed = Duration.zero;
      seasonClock = () => DateTime(2026, 11, 2, 23, 59).add(elapsed);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);
      await swipeToNextPage(tester);
      expect(find.text('The Spooky theme is here'), findsOneWidget);

      elapsed = const Duration(minutes: 1);
      await tester.pump(const Duration(minutes: 1));

      expect(find.text('The Spooky theme is here'), findsNothing);
    });

    testWidgets('hides the card when the Spooky theme is already active', (tester) async {
      seasonClock = () => DateTime(2026, 10, 31);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], theme: kDarkTheme9);

      expect(find.text('The Spooky theme is here'), findsNothing);
    });

    testWidgets('tap requests the Spooky dark theme and mode in one event', (tester) async {
      seasonClock = () => DateTime(2026, 10, 31);
      final _MockThemeBloc themeBloc = _MockThemeBloc();
      when(() => themeBloc.state).thenReturn(ThemeState.initial());
      registerFallbackValue(const ThemeViewRoute());
      final _MockStackRouter router = _MockStackRouter();
      when(() => router.push(any())).thenAnswer((_) async => null);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], router: router, themeBloc: themeBloc);
      await swipeToNextPage(tester);

      await tester.tap(find.text('The Spooky theme is here'));

      verify(
        () => themeBloc.add(const ThemeEvent.darkThemeChanged(themeId: prismSpookyThemeId, mode: ThemeMode.dark)),
      ).called(1);
      verifyNever(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.dark)));
    });
  });

  group('Diwali theme card', () {
    testWidgets('shows the card in the season when the theme is not Diwali', (tester) async {
      seasonClock = () => DateTime(2026, 11, 5);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);

      expect(find.text('The Diwali theme is here'), findsOneWidget);
    });

    testWidgets('hides the card once the season has ended', (tester) async {
      seasonClock = () => DateTime(2026, 11, 12);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);

      expect(find.text('The Diwali theme is here'), findsNothing);
    });

    testWidgets('removes the card at the season deadline without another parent rebuild', (tester) async {
      Duration elapsed = Duration.zero;
      seasonClock = () => DateTime(2026, 11, 11, 23, 59).add(elapsed);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);
      expect(find.text('The Diwali theme is here'), findsOneWidget);

      elapsed = const Duration(minutes: 1);
      await tester.pump(const Duration(minutes: 1));

      expect(find.text('The Diwali theme is here'), findsNothing);
    });

    testWidgets('hides the card when the Diwali theme is already active', (tester) async {
      seasonClock = () => DateTime(2026, 11, 5);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], theme: kDarkTheme10);

      expect(find.text('The Diwali theme is here'), findsNothing);
    });

    testWidgets('tap requests the Diwali dark theme and mode in one event', (tester) async {
      seasonClock = () => DateTime(2026, 11, 5);
      final _MockThemeBloc themeBloc = _MockThemeBloc();
      when(() => themeBloc.state).thenReturn(ThemeState.initial());
      registerFallbackValue(const ThemeViewRoute());
      final _MockStackRouter router = _MockStackRouter();
      when(() => router.push(any())).thenAnswer((_) async => null);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')], router: router, themeBloc: themeBloc);

      await tester.tap(find.byType(FeedHeroCard).first);

      verify(
        () => themeBloc.add(const ThemeEvent.darkThemeChanged(themeId: prismDiwaliThemeId, mode: ThemeMode.dark)),
      ).called(1);
      verifyNever(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.dark)));
    });

    testWidgets('on 31 October the Diwali card comes before the Spooky card', (tester) async {
      seasonClock = () => DateTime(2026, 10, 31);
      await pumpCarousel(tester, <PrismFeedItem>[_wall('a')]);

      expect(find.text('The Diwali theme is here'), findsOneWidget);
      expect(find.text('The Spooky theme is here'), findsNothing);

      await swipeToNextPage(tester);

      expect(find.text('The Spooky theme is here'), findsOneWidget);
    });
  });
}
