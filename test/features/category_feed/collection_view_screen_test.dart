import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/collections_view_grid.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/fake_user_block_repository.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

void main() {
  late FakeFirestoreClient firestore;
  late _MockCategoryFeedBloc bloc;

  setUp(() {
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    AnalyticsRuntime.instance = FakeAppAnalytics();
    bloc = _MockCategoryFeedBloc();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, String name, CategoryFeedState state) {
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CategoryFeedState>.empty(), initialState: state);
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CategoryFeedBloc>.value(
          value: bloc,
          child: CollectionViewScreen(collectionName: name),
        ),
      ),
    );
  }

  testWidgets('a collection shows its name as the title, then an empty state when it has no wallpapers', (
    tester,
  ) async {
    await pumpScreen(tester, 'amoled', CategoryFeedState.initial());

    expect(find.text('Amoled'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CollectionViewGrid), findsOneWidget);
    expect(find.widgetWithText(GlintState, 'Nothing in this collection yet'), findsOneWidget);
  });

  testWidgets('a collection that fails to load shows an error and retries on tap', (tester) async {
    firestore.queryError = Exception('offline');
    await pumpScreen(tester, 'amoled', CategoryFeedState.initial());
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

  testWidgets('a category shows the skeleton while loading', (tester) async {
    await pumpScreen(tester, 'category:Anime', CategoryFeedState.initial());

    expect(find.text('Anime'), findsOneWidget);
    expect(find.byType(LoadingCards), findsOneWidget);
  });

  testWidgets('a failed category feed shows an offline state that asks the bloc to refresh', (tester) async {
    await pumpScreen(tester, 'category:Anime', CategoryFeedState.initial().copyWith(status: LoadStatus.failure));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(GlintState, "Can't reach the servers"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const CategoryFeedEvent.refreshRequested())).called(1);
  });
}
