import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

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

void main() {
  const Size screen = Size(400, 800);

  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  /// The first page is the promo banner, then one page per wall. Reduce motion keeps autoplay off.
  Future<void> pumpCarousel(WidgetTester tester, List<PrismFeedItem> walls) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wotd = _MockWotdBloc();
    when(() => wotd.state).thenReturn(WotdState.initial().copyWith(status: LoadStatus.initial));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: Scaffold(
          body: BlocProvider<WotdBloc>.value(
            value: wotd,
            child: Align(
              alignment: Alignment.topCenter,
              child: FeedCarousel(previewWalls: walls),
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

  testWidgets('a page is as wide as the screen and 0.6 times as tall, with no margin', (tester) async {
    await pumpCarousel(tester, <PrismFeedItem>[_wall('a'), _wall('b')]);

    expect(tester.getRect(find.byType(FeedHeroCard).first), const Rect.fromLTWH(0, 0, 400, 240));
    expect(find.descendant(of: find.byType(FeedHeroCard), matching: find.byType(ClipRRect)), findsNothing);
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

  testWidgets('a single page has no dots', (tester) async {
    await pumpCarousel(tester, const <PrismFeedItem>[]);

    expect(find.byType(FeedCarouselDots), findsNothing);
  });
}
