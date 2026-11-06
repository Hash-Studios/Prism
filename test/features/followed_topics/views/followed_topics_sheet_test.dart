import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/followed_topics/views/widgets/followed_topics_sheet.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_firestore_client.dart';
import '../../../support/in_memory_local_store.dart';
import '../../../support/profile_user_fixture.dart';
import '../support/transaction_firestore_client.dart';

Widget _app(Widget home, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(body: home),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestoreClient firestore;
  late FollowedTopicsStore store;

  // The sheet reads the store; the settings row normally loads it, so the tests load it here.
  Future<void> seedTopics(List<String> keys) async {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{'followedTopics': keys},
    };
    await store.ensureLoaded();
  }

  // Prism sheets need a sheet route (smooth_sheets reads its layout from it), so open the sheet from a button.
  Future<void> openSheet(WidgetTester tester, {TextScaler textScaler = TextScaler.noScaling}) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPrismSheet<void>(context, builder: (_) => const FollowedTopicsSheet()),
            child: const Text('Open'),
          ),
        ),
        textScaler: textScaler,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    firestore = TransactionFirestoreClient();
    store = FollowedTopicsStore(SettingsLocalDataSource(InMemoryLocalStore()), firestore);
    getIt.registerSingleton<FollowedTopicsStore>(store);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (MethodCall call) async => true,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  group('FollowedTopicsSettingsRow', () {
    testWidgets('a guest sees no row', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();

      await tester.pumpWidget(_app(const FollowedTopicsSettingsRow()));
      await tester.pumpAndSettle();

      expect(find.text('Topics you follow'), findsNothing);
    });

    testWidgets('a signed-in user with 2 topics sees the row with 2 topics', (tester) async {
      app_state.prismUser = profileUser();
      await seedTopics(<String>['category:Pastel', 'mood:dreamy']);

      await tester.pumpWidget(_app(const FollowedTopicsSettingsRow()));
      await tester.pumpAndSettle();

      expect(find.text('Topics you follow'), findsOneWidget);
      expect(find.text('2 topics'), findsOneWidget);
    });

    testWidgets('1 topic is shown in the singular', (tester) async {
      app_state.prismUser = profileUser();
      await seedTopics(<String>['category:Pastel']);

      await tester.pumpWidget(_app(const FollowedTopicsSettingsRow()));
      await tester.pumpAndSettle();

      expect(find.text('1 topic'), findsOneWidget);
    });

    testWidgets('a signed-in user with no topics sees None yet', (tester) async {
      app_state.prismUser = profileUser();

      await tester.pumpWidget(_app(const FollowedTopicsSettingsRow()));
      await tester.pumpAndSettle();

      expect(find.text('None yet'), findsOneWidget);
    });
  });

  group('FollowedTopicsSheet', () {
    testWidgets('lists each topic with its kind, in follow order', (tester) async {
      app_state.prismUser = profileUser();
      await seedTopics(<String>['category:Pastel', 'mood:dreamy']);

      await openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('Pastel'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Dreamy'), findsOneWidget);
      expect(find.text('Mood'), findsOneWidget);
    });

    testWidgets('Unfollow removes the topic from the list and from the store', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      app_state.prismUser = profileUser();
      await seedTopics(<String>['category:Pastel', 'mood:dreamy']);

      await openSheet(tester);
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('Unfollow Pastel'));
      await tester.pumpAndSettle();

      expect(find.text('Pastel'), findsNothing);
      expect(find.text('Dreamy'), findsOneWidget);
      expect(store.topics, <FollowedTopic>[FollowedTopic.mood(WallMood.dreamy)]);
      semantics.dispose();
    });

    testWidgets('with no topics it shows No topics yet', (tester) async {
      app_state.prismUser = profileUser();

      await openSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('No topics yet'), findsOneWidget);
    });

    testWidgets('the large text setting does not overflow the sheet', (tester) async {
      app_state.prismUser = profileUser();
      await seedTopics(<String>['category:Pastel', 'mood:dreamy']);

      await openSheet(tester, textScaler: const TextScaler.linear(2));
      await tester.pumpAndSettle();

      expect(find.text('Pastel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
