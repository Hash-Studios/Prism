import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

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
  late _MockCategoryFeedBloc bloc;
  late StreamController<CategoryFeedState> states;
  late CategoryFeedState current;

  setUpAll(() => registerFallbackValue(const CategoryFeedEvent.started()));

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    bloc = _MockCategoryFeedBloc();
    states = StreamController<CategoryFeedState>.broadcast(sync: true);
    when(() => bloc.state).thenAnswer((_) => current);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await states.close();
  });

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<CategoryFeedBloc>.value(
        value: bloc,
        child: const CollectionViewScreen(collectionName: 'category:Dark'),
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

    expect(find.text("Couldn't load wallpapers"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a category name that is not in the list shows the first category, as before', (tester) async {
    current = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[_space, _dark],
      selectedCategory: _space,
      items: <FeedItemEntity>[],
    );
    when(() => bloc.add(any())).thenAnswer((_) => states.add(current));

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CategoryFeedBloc>.value(
          value: bloc,
          child: const CollectionViewScreen(collectionName: 'category:Unknown'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingCards), findsNothing);
    expect(find.text('No wallpapers here yet'), findsOneWidget);
  });
}
