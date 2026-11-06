import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/followed_topics/views/widgets/topic_follow_button.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_feed_cache_local_data_source.dart';
import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/profile_user_fixture.dart';
import '../support/transaction_firestore_client.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

const CategoryEntity _pastelCategory = CategoryEntity(
  name: 'Pastel',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.search,
  image: '',
  image2: '',
);
const CategoryEntity _amoledCategory = CategoryEntity(
  name: 'AMOLED',
  source: WallpaperSource.prism,
  searchType: CategorySearchType.search,
  image: '',
  image2: '',
);

Widget _app(Widget home, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(body: Center(child: home)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestoreClient firestore;
  late FollowedTopicsStore store;
  late FollowedTopic pastel;
  final Future<bool> Function(BuildContext) originalSignIn = signedInActionSignIn;

  setUp(() {
    firestore = TransactionFirestoreClient();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FollowedTopicsStore(settings, firestore);
    pastel = FollowedTopic.category('Pastel')!;
    getIt.registerSingleton<FollowedTopicsStore>(store);
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<FeedCacheLocalDataSource>(FakeFeedCacheLocalDataSource());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = profileUser();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (MethodCall call) async => true,
    );
  });

  tearDown(() async {
    signedInActionSignIn = originalSignIn;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  testWidgets('a signed-in tap follows the topic and the label changes to Following', (tester) async {
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(store.topics, <FollowedTopic>[pastel]);
    // The success toast leaves a one second timer in fluttertoast. Let it finish.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a guest tap asks for sign-in once, and with no sign-in the button stays Follow with no write', (
    tester,
  ) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    int prompts = 0;
    signedInActionSignIn = (_) async {
      prompts++;
      return false;
    };
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(prompts, 1);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
    expect(firestore.writes, isEmpty);
    expect(store.topics, isEmpty);
  });

  testWidgets('the semantics label is Follow Pastel, then Unfollow Pastel after the tap', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Follow Pastel'), findsOneWidget);

    // A screen reader activates the button through its semantics tap action.
    tester.semantics.tap(find.semantics.byLabel('Follow Pastel'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Unfollow Pastel'), findsOneWidget);
    expect(find.bySemanticsLabel('Follow Pastel'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });

  testWidgets('the large text setting does not overflow the button', (tester) async {
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel), textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.text('Follow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('on a category page header', () {
    late _MockCategoryFeedBloc bloc;
    late StreamController<CategoryFeedState> states;
    late CategoryFeedState current;

    setUpAll(() => registerFallbackValue(const CategoryFeedEvent.started()));

    setUp(() {
      bloc = _MockCategoryFeedBloc();
      current = CategoryFeedState.initial();
      states = StreamController<CategoryFeedState>.broadcast(sync: true);
      when(() => bloc.state).thenAnswer((_) => current);
      when(() => bloc.stream).thenAnswer((_) => states.stream);
    });

    tearDown(() async {
      await states.close();
    });

    Future<void> pumpCategoryPage(WidgetTester tester, String name, CategoryEntity category) async {
      current = CategoryFeedState.initial().copyWith(
        status: LoadStatus.success,
        categories: <CategoryEntity>[category],
        selectedCategory: category,
        items: <FeedItemEntity>[],
      );
      when(() => bloc.add(any())).thenAnswer((_) => states.add(current));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<CategoryFeedBloc>.value(
            value: bloc,
            child: CollectionViewScreen(collectionName: name),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the Pastel category page shows Follow in the header', (tester) async {
      await pumpCategoryPage(tester, 'category:Pastel', _pastelCategory);

      expect(find.text('Pastel'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('the AMOLED category page shows no Follow, because it has no Prism walls', (tester) async {
      await pumpCategoryPage(tester, 'category:AMOLED', _amoledCategory);

      expect(find.text('AMOLED'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });
  });
}
