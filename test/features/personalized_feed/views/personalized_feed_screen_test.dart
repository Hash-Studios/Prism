import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_hero_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeedBloc extends MockBloc<PersonalizedFeedEvent, PersonalizedFeedState> implements PersonalizedFeedBloc {}

class _MockWotdBloc extends MockBloc<WotdEvent, WotdState> implements WotdBloc {}

FeedItemEntity _item(int i, {List<String>? collections}) => FeedItemEntity.prism(
  id: 'w$i',
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: 'w$i',
      source: WallpaperSource.prism,
      fullUrl: '',
      thumbnailUrl: '',
      authorName: 'Ana',
      category: 'Nature',
    ),
    collections: collections,
  ),
);

void main() {
  late _MockFeedBloc bloc;
  late _MockWotdBloc wotd;

  setUp(() {
    bloc = _MockFeedBloc();
    wotd = _MockWotdBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => wotd.state).thenReturn(WotdState.initial());
    getIt.registerSingleton<PersonalizedFeedBloc>(bloc);
  });
  tearDown(getIt.reset);

  Future<void> pumpFeed(WidgetTester tester, PersonalizedFeedState state, {VoidCallback? onTuneTap}) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(bloc, const Stream<PersonalizedFeedState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<WotdBloc>.value(
          value: wotd,
          child: Scaffold(body: PersonalizedFeedScreen(onTuneTap: onTuneTap)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('loading shows a skeleton, not a spinner', (tester) async {
    await pumpFeed(tester, PersonalizedFeedState.initial().copyWith(status: LoadStatus.loading));

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('For you'), findsNothing);
  });

  testWidgets('an error with no items shows Glint and a retry that refreshes the feed', (tester) async {
    await pumpFeed(tester, PersonalizedFeedState.initial().copyWith(status: LoadStatus.failure));

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text("Couldn't load your feed"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const PersonalizedFeedEvent.refreshRequested())).called(1);
  });

  testWidgets('a feed with no items explains how to shape it and opens the tune sheet', (tester) async {
    var tuned = 0;
    await pumpFeed(
      tester,
      PersonalizedFeedState.initial().copyWith(status: LoadStatus.success, hasMore: false),
      onTuneTap: () => tuned++,
    );

    expect(find.text('Shape this feed'), findsOneWidget);
    await tester.tap(find.text('Tune your feed').last);
    expect(tuned, 1);
  });

  testWidgets('content shows the For you header, a tune button, the grid and the caught up state', (tester) async {
    var tuned = 0;
    await pumpFeed(
      tester,
      PersonalizedFeedState.initial().copyWith(
        status: LoadStatus.success,
        hasMore: false,
        items: <FeedItemEntity>[for (int i = 0; i < 10; i++) _item(i)],
      ),
      onTuneTap: () => tuned++,
    );

    expect(find.text('For you'), findsOneWidget);
    await tester.tap(find.byTooltip('Tune your feed'));
    expect(tuned, 1);
    expect(find.byType(FeedWallTile), findsWidgets);
    expect(find.byType(PrismWallTile), findsWidgets);
    await tester.scrollUntilVisible(find.text('You are all caught up'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('You are all caught up'), findsOneWidget);
  });

  testWidgets('fetching more shows skeleton tiles, not a spinner', (tester) async {
    await pumpFeed(
      tester,
      PersonalizedFeedState.initial().copyWith(
        status: LoadStatus.success,
        isFetchingMore: true,
        items: <FeedItemEntity>[for (int i = 0; i < 10; i++) _item(i)],
      ),
    );
    await tester.scrollUntilVisible(find.byType(PrismSkeleton), 300, scrollable: find.byType(Scrollable).first);

    expect(find.byType(PrismSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the carousel shows Wall of the Day first, with dots under the card', (tester) async {
    when(() => wotd.state).thenReturn(
      WotdState.initial().copyWith(
        status: LoadStatus.success,
        entity: const WallOfTheDayEntity(wallId: 'wotd-1', url: '', thumbnailUrl: '', photographer: 'Ana'),
      ),
    );
    await pumpFeed(
      tester,
      PersonalizedFeedState.initial().copyWith(
        status: LoadStatus.success,
        items: <FeedItemEntity>[for (int i = 0; i < 10; i++) _item(i)],
      ),
    );

    expect(find.text('Wall of the day'), findsOneWidget);
    expect(find.text('by Ana'), findsOneWidget);
    final Size card = tester.getSize(find.byType(FeedHeroCard).first);
    expect(card.width, 390 - 2 * PrismWallGrid.margin);
    expect(card.height / card.width, closeTo(0.56, 0.01));
  });

  testWidgets('only a premium wallpaper gets the gold star badge', (tester) async {
    await pumpFeed(
      tester,
      PersonalizedFeedState.initial().copyWith(
        status: LoadStatus.success,
        hasMore: false,
        items: <FeedItemEntity>[
          for (int i = 0; i < 6; i++) _item(i),
          _item(6, collections: const <String>['space']),
        ],
      ),
    );

    expect(find.byType(PremiumStarBadge), findsOneWidget);
  });
}
