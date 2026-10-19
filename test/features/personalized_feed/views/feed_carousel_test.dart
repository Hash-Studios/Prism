import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/widgets/drop_carousel_slide.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
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

class _MockStackRouter extends Mock implements StackRouter {}

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
  });
  tearDown(AnalyticsRuntime.reset);

  /// The first page is the promo banner, then one page per wall. Reduce motion keeps autoplay off.
  Future<void> pumpCarousel(
    WidgetTester tester,
    List<PrismFeedItem> walls, {
    Size size = screen,
    bool reduceMotion = true,
    List<PrismWallpaper> boosted = const <PrismWallpaper>[],
    WallOfTheDayEntity? wotdEntity,
    DropEntity? liveDrop,
    StackRouter? router,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wotd = _MockWotdBloc();
    when(() => wotd.state).thenReturn(
      WotdState.initial().copyWith(
        status: wotdEntity == null ? LoadStatus.initial : LoadStatus.success,
        entity: wotdEntity,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: BlocProvider<WotdBloc>.value(
            value: wotd,
            child: Align(
              alignment: Alignment.topCenter,
              child: router == null
                  ? FeedCarousel(previewWalls: walls, boostedWalls: boosted, liveDrop: liveDrop)
                  : StackRouterScope(
                      controller: router,
                      stateHash: 0,
                      child: FeedCarousel(previewWalls: walls, boostedWalls: boosted, liveDrop: liveDrop),
                    ),
            ),
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

  testWidgets('the banner page keeps its remote title', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);

    expect(find.text('Join our Telegram'), findsOneWidget);
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
}
