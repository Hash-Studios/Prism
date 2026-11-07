import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/data/collections/provider/collections_without_provider.dart' as c_data;
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_grid.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_feed_cache_local_data_source.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';
import '../../support/in_memory_local_store.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

const CategoryEntity _space = CategoryEntity(
  name: 'Space',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.search,
  image: '',
  image2: '',
);
const CategoryEntity _dark = CategoryEntity(
  name: 'Dark',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.search,
  image: '',
  image2: '',
);
const CategoryEntity _desktop = CategoryEntity(
  name: 'Desktop',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.desktop,
  image: '',
  image2: '',
);

void main() {
  late FakeFirestoreClient firestore;
  late _MockCategoryFeedBloc bloc;
  late StreamController<CategoryFeedState> states;
  late CategoryFeedState current;

  setUpAll(() => registerFallbackValue(const CategoryFeedEvent.started()));

  setUp(() {
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<FeedCacheLocalDataSource>(FakeFeedCacheLocalDataSource());
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    AnalyticsRuntime.instance = FakeAppAnalytics();
    bloc = _MockCategoryFeedBloc();
    current = CategoryFeedState.initial();
    states = StreamController<CategoryFeedState>.broadcast(sync: true);
    when(() => bloc.state).thenAnswer((_) => current);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await states.close();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, [String name = 'category:Dark', bool reduceMotion = false]) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),

          home: BlocProvider<CategoryFeedBloc>.value(
            value: bloc,
            child: CollectionViewScreen(collectionName: name),
          ),
        ),
      );

  testWidgets('shows loading, not the previous category, until the bloc selects this category', (tester) async {
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[_space, _dark],
      selectedCategory: _space,
      items: <FeedItemEntity>[],
    );
    when(() => bloc.add(any())).thenAnswer((_) {
      current = current.copyWith(selectedCategory: _dark, status: LoadStatus.success, items: <FeedItemEntity>[]);
      states.add(current);
    });

    await pumpScreen(tester);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget, reason: 'the first frame still holds Space');
    expect(find.text('No wallpapers here yet'), findsNothing);

    await tester.pump();
    expect(find.text('No wallpapers here yet'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LoadingCards), findsNothing, reason: 'the skeleton crossfades out');
  });

  testWidgets('a Prism category of the desktop type shows the desktop grid', (tester) async {
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[_space, _desktop],
      selectedCategory: _desktop,
      items: <FeedItemEntity>[],
    );
    when(() => bloc.add(any())).thenAnswer((_) => states.add(current));

    await pumpScreen(tester, 'category:Desktop');
    await tester.pump();

    expect(tester.widget<WallpaperGrid>(find.byType(WallpaperGrid)).desktopDownload, isTrue);
  });

  testWidgets('a Prism category of the search type shows the wallpaper grid', (tester) async {
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[_space, _dark],
      selectedCategory: _dark,
      items: <FeedItemEntity>[],
    );
    when(() => bloc.add(any())).thenAnswer((_) => states.add(current));

    await pumpScreen(tester);
    await tester.pump();

    expect(tester.widget<WallpaperGrid>(find.byType(WallpaperGrid)).desktopDownload, isFalse);
  });

  testWidgets('a failed category list shows the error, not an endless skeleton', (tester) async {
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.failure,
      categories: const <CategoryEntity>[_space],
    );
    when(() => bloc.add(any())).thenAnswer((_) => states.add(current));

    await pumpScreen(tester);
    await tester.pump();

    expect(find.widgetWithText(GlintState, "Couldn't load wallpapers"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    verify(() => bloc.add(any())).called(2);
  });

  testWidgets('a category name that is not in the list shows the first category, as before', (tester) async {
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[_space, _dark],
      selectedCategory: _space,
      items: <FeedItemEntity>[],
    );
    when(() => bloc.add(any())).thenAnswer((_) => states.add(current));

    await pumpScreen(tester, 'category:Unknown');
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.text('No wallpapers here yet'), findsOneWidget);
  });

  testWidgets('a hidden Desktop deep link uses the first listed category fallback', (tester) async {
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[_space, _dark],
      selectedCategory: _space,
      items: <FeedItemEntity>[],
    );
    when(() => bloc.add(any())).thenAnswer((_) => states.add(current));

    await pumpScreen(tester, 'category:Desktop');
    await tester.pump();

    verify(() => bloc.add(CategoryFeedEvent.categorySelected(category: _space))).called(1);
  });

  testWidgets('a collection shows its name as the title, then an empty state when it has no wallpapers', (
    tester,
  ) async {
    await pumpScreen(tester, 'amoled');

    expect(find.text('Amoled'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CollectionViewGrid), findsOneWidget);
    expect(find.widgetWithText(GlintState, 'No collections yet'), findsOneWidget);
  });

  testWidgets('a collection that fails to load shows an error and retries on tap', (tester) async {
    firestore.queryError = Exception('offline');
    await pumpScreen(tester, 'amoled');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Couldn't load this collection"), findsOneWidget);

    firestore.queryError = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CollectionViewGrid), findsOneWidget);
  });

  testWidgets('a category with a cover shows it as the header with tinted blocks while loading', (tester) async {
    const CategoryEntity covered = CategoryEntity(
      name: 'Dark',
      source: WallpaperSource.prism,
      searchType: CategorySearchType.search,
      image: 'https://images.pexels.com/photos/1616403/x.jpeg',
      image2: '',
    );
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[covered, _space],
      selectedCategory: _space,
      items: <FeedItemEntity>[],
    );
    when(() => bloc.add(any())).thenAnswer((_) {});

    await pumpScreen(tester);

    expect(find.byType(LoadingCards), findsNothing, reason: 'the cover header replaces the grey skeleton');
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);

    states.add(current.copyWith(selectedCategory: covered));
    await tester.pump(const Duration(seconds: 31));
  });

  group('a collection opened from the Collections tab', () {
    const String cover = 'https://images.pexels.com/photos/1616403/x.jpeg';
    Finder header() => find.byType(AspectRatio);

    setUp(() {
      c_data.collections = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Abstract', 'thumb1': cover},
      ];
    });
    tearDown(() => c_data.collections = <Map<String, dynamic>>[]);

    Future<void> pumpUntilGrid(WidgetTester tester) async {
      for (int i = 0; i < 20 && find.byType(CollectionViewGrid).evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(find.byType(CollectionViewGrid), findsOneWidget);
    }

    testWidgets('opens on its cover header, though the route lowercases the name', (tester) async {
      await pumpScreen(tester, 'abstract');

      expect(find.byType(LoadingCards), findsNothing, reason: 'no grey skeleton before the cover');
      expect(header(), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the placeholder crossfades into the walls', (tester) async {
      await pumpScreen(tester, 'abstract');
      await pumpUntilGrid(tester);
      await tester.pump(const Duration(milliseconds: 60));
      expect(header(), findsOneWidget, reason: 'the placeholder fades out under the walls');

      await tester.pump(const Duration(milliseconds: 200));
      expect(header(), findsNothing);
    });

    testWidgets('the header and the blocks share one colour that eases into the cover tint', (tester) async {
      const CategoryEntity covered = CategoryEntity(
        name: 'Dark',
        source: WallpaperSource.prism,
        searchType: CategorySearchType.search,
        image: cover,
        image2: '',
      );
      current = CategoryFeedState.initial().copyWith(
        status: LoadStatus.success,
        categories: const <CategoryEntity>[covered, _space],
        selectedCategory: _space,
        items: <FeedItemEntity>[],
      );
      when(() => bloc.add(any())).thenAnswer((_) {});
      await pumpScreen(tester);
      Color headerColour() =>
          tester.widget<ColoredBox>(find.descendant(of: header(), matching: find.byType(ColoredBox)).first).color;
      Color? blockColour() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(of: find.byType(GridView), matching: find.byType(DecoratedBox)).first,
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      final Color neutral = headerColour();
      expect(blockColour(), neutral);

      // Decodes the bundled cover for real, so the dominant colour resolves.
      for (int i = 0; i < 20 && headerColour() == neutral; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 60));
      expect(headerColour(), isNot(neutral), reason: 'the tint has started');
      expect(headerColour(), blockColour(), reason: 'the header does not jump ahead of the blocks');

      await tester.pump(const Duration(milliseconds: 200));
      final Color tint = headerColour();
      expect(blockColour(), tint);

      // A second visit knows the colour, so it opens on the tint with no neutral frame.
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester);
      expect(headerColour(), tint);
      expect(blockColour(), tint);

      states.add(current.copyWith(selectedCategory: covered));
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('with reduce motion on, the walls replace the placeholder at once', (tester) async {
      await pumpScreen(tester, 'abstract', true);
      expect(header(), findsOneWidget);
      await pumpUntilGrid(tester);
      await tester.pump();
      expect(header(), findsNothing);
    });
  });
}
