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
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/features/hints/views/feature_hint.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_feed_cache_local_data_source.dart';
import '../../../support/fake_user_block_repository.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/profile_user_fixture.dart';
import '../support/transaction_firestore_client.dart';

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _HoldingFollowFirestore extends TransactionFirestoreClient {
  Completer<void>? followGate;
  Completer<void>? loadGate;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    if (sourceTag == 'followed_topics.load') await loadGate?.future;
    return super.getById(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction transaction) action, {
    required String sourceTag,
    required String collection,
    String? docId,
  }) async {
    if (sourceTag == 'followed_topics.follow') await followGate?.future;
    return super.runTransaction(action, sourceTag: sourceTag, collection: collection, docId: docId);
  }
}

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

  late _HoldingFollowFirestore firestore;
  late FollowedTopicsStore store;
  late FollowedTopic pastel;
  late FakeAppAnalytics analytics;
  final Future<bool> Function(BuildContext) originalSignIn = signedInActionSignIn;

  setUp(() {
    firestore = _HoldingFollowFirestore();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    store = FollowedTopicsStore(settings, firestore);
    pastel = FollowedTopic.category('Pastel')!;
    getIt.registerSingleton<FollowedTopicsStore>(store);
    getIt.registerSingleton<FirestoreClient>(firestore);
    getIt.registerSingleton<FeedCacheLocalDataSource>(FakeFeedCacheLocalDataSource());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
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

  testWidgets('Follow button carries the followCategory feature hint, on for an unfollowed category only', (
    tester,
  ) async {
    Finder hintOf(Finder control) => find.ancestor(
      of: control,
      matching: find.byWidgetPredicate((Widget w) => w is FeatureHint && w.id == HintId.followCategory),
    );

    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpAndSettle();
    expect(hintOf(find.text('Follow')), findsOneWidget);
    expect(tester.widget<FeatureHint>(hintOf(find.text('Follow'))).enabled, isTrue);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(hintOf(find.text('Following')), findsOneWidget);
    expect(tester.widget<FeatureHint>(hintOf(find.text('Following'))).enabled, isFalse);
    // The success toast leaves a one second timer in fluttertoast. Let it finish.
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(_app(TopicFollowButton(topic: FollowedTopic.mood(WallMood.dreamy))));
    await tester.pumpAndSettle();
    expect(hintOf(find.text('Follow')), findsOneWidget);
    expect(tester.widget<FeatureHint>(hintOf(find.text('Follow'))).enabled, isFalse);
  });

  testWidgets('the follow hint waits for the account follow list', (tester) async {
    firestore.loadGate = Completer<void>();
    firestore.docs['usersv2/${app_state.prismUser.id}/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>[pastel.key],
      },
    };
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pump(const Duration(milliseconds: 701));
    final Finder hint = find.byWidgetPredicate((Widget w) => w is FeatureHint && w.id == HintId.followCategory);
    final bool hintEnabledBeforeLoad = tester.widget<FeatureHint>(hint).enabled;
    firestore.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(hintEnabledBeforeLoad, isFalse);
    expect(find.text('Following'), findsOneWidget);
    expect(tester.widget<FeatureHint>(hint).enabled, isFalse);
  });

  testWidgets('opening a topic still marks it seen when loading finishes after page removal', (tester) async {
    final String userId = app_state.prismUser.id;
    final String seenKey = 'followed_topics.seen.$userId.${pastel.key}';
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    await settings.set(seenKey, 1);
    firestore.loadGate = Completer<void>();
    firestore.docs['usersv2/$userId/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>[pastel.key],
      },
    };
    firestore.docs['topicNews'] = <String, Map<String, dynamic>>{
      'current': <String, dynamic>{
        'latest': <String, int>{pastel.key: 2},
      },
    };
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    firestore.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(settings.get<int>(seenKey), 2);
    expect(store.hasNew(pastel), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the follow hint is off while sign-in disables its control', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final Completer<bool> signIn = Completer<bool>();
    signedInActionSignIn = (_) => signIn.future;
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow'));
    await tester.pump();
    final Finder hint = find.byWidgetPredicate((Widget w) => w is FeatureHint && w.id == HintId.followCategory);
    final bool hintEnabledWhileBusy = tester.widget<FeatureHint>(hint).enabled;
    signIn.complete(false);
    await tester.pumpAndSettle();
    expect(hintEnabledWhileBusy, isFalse);
    expect(tester.widget<FeatureHint>(hint).enabled, isTrue);
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
    expect(analytics.events.where((event) => event.eventName == 'topic_followed'), hasLength(1));
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
    expect(store.topics, <FollowedTopic>[pastel]);
    expect(analytics.events.where((event) => event.eventName == 'topic_followed'), hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });

  testWidgets('repeated activations share one sign-in prompt and stay disabled until it closes', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    app_state.prismUser = app_constants.createGuestPrismUser();
    final Completer<bool> signIn = Completer<bool>();
    int prompts = 0;
    signedInActionSignIn = (_) {
      prompts++;
      return signIn.future;
    };
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpAndSettle();

    tester.semantics.tap(find.semantics.byLabel('Follow Pastel'));
    tester.semantics.tap(find.semantics.byLabel('Follow Pastel'));
    await tester.tap(find.text('Follow'));
    await tester.pump();
    final int promptsWhilePending = prompts;
    final bool canTapWhilePending = tester
        .getSemantics(find.bySemanticsLabel('Follow Pastel'))
        .getSemanticsData()
        .hasAction(SemanticsAction.tap);
    signIn.complete(false);
    await tester.pumpAndSettle();

    expect(promptsWhilePending, 1);
    expect(canTapWhilePending, isFalse);
    expect(store.topics, isEmpty);
    expect(firestore.writes, isEmpty);
    tester.semantics.tap(find.semantics.byLabel('Follow Pastel'));
    await tester.pumpAndSettle();
    expect(prompts, 2, reason: 'cancelling sign-in releases the busy guard');
    semantics.dispose();
  });

  testWidgets('a follow stays busy through its save and ignores the old physical button', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(TopicFollowButton(topic: pastel)));
    await tester.pumpAndSettle();
    firestore.followGate = Completer<void>();

    tester.semantics.tap(find.semantics.byLabel('Follow Pastel'));
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    final bool canTapWhileSaving = tester
        .getSemantics(find.bySemanticsLabel('Unfollow Pastel'))
        .getSemanticsData()
        .hasAction(SemanticsAction.tap);
    expect(analytics.events, isEmpty);
    firestore.followGate!.complete();
    await tester.pumpAndSettle();

    expect(canTapWhileSaving, isFalse);
    expect(store.topics, <FollowedTopic>[pastel]);
    expect(analytics.events.where((event) => event.eventName == 'topic_followed'), hasLength(1));
    expect(analytics.events.where((event) => event.eventName == 'topic_unfollowed'), isEmpty);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Unfollow Pastel')).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
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
