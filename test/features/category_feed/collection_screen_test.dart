import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/collection_card.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

void main() {
  late FakeFirestoreClient firestore;
  late _MockCategoryFeedBloc bloc;

  setUp(() {
    firestore = FakeFirestoreClient(
      onQuery: (_) => <FakeDocRow>[
        (id: 'flat', data: <String, dynamic>{'name': 'Flat', 'thumb1': '', 'premium': false}),
        (id: 'gradients', data: <String, dynamic>{'name': 'Gradients', 'thumb1': '', 'premium': true}),
      ],
    );
    getIt.registerSingleton<FirestoreClient>(firestore);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    bloc = _MockCategoryFeedBloc();
    final state = CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[
        CategoryEntity(
          name: 'Anime',
          source: WallpaperSource.wallhaven,
          searchType: CategorySearchType.search,
          image: '',
          image2: '',
        ),
      ],
    );
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CategoryFeedState>.empty(), initialState: state);
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<CategoryFeedBloc>.value(value: bloc, child: const CollectionScreen()),
        ),
      ),
    );
  }

  testWidgets('shows card skeletons under the title while collections load', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Collections'), findsOneWidget);
    expect(find.byType(CollectionsSkeleton), findsOneWidget);
    expect(find.byType(CollectionCard), findsNothing);
    await tester.pump();
  });

  testWidgets('lists collections, then categories, with a lock on premium collections', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Collections'), findsOneWidget);
    expect(find.byType(CollectionsSkeleton), findsNothing);
    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Gradients'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.bySemanticsLabel('Premium collection, Gradients'), findsOneWidget);
    expect(find.bySemanticsLabel('Category, Anime'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows a retry when the servers are unreachable and recovers on tap', (tester) async {
    firestore.queryError = Exception('offline');
    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Collections'), findsOneWidget);
    expect(find.widgetWithText(GlintState, "Can't reach the servers"), findsOneWidget);

    firestore.queryError = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(GlintState), findsNothing);
    expect(find.text('Flat'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no collections and no categories', (tester) async {
    firestore.onQuery = (_) => const <FakeDocRow>[];
    final state = CategoryFeedState.initial().copyWith(status: LoadStatus.success);
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CategoryFeedState>.empty(), initialState: state);

    await pumpScreen(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, 'No collections yet'), findsOneWidget);
  });
}
