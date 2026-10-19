import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
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

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

const CategoryEntity _space = CategoryEntity(
  name: 'Space',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.nonSearch,
  image: '',
  image2: '',
);
const CategoryEntity _dark = CategoryEntity(
  name: 'Dark',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.nonSearch,
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

  Future<void> pumpScreen(WidgetTester tester, [String name = 'category:Dark']) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

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
    expect(find.byType(LoadingCards), findsNothing);
    expect(find.text('No wallpapers here yet'), findsOneWidget);
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
}
