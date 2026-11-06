import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/views/widgets/following_topics_row.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';
import '../../../support/profile_user_fixture.dart';
import '../support/transaction_firestore_client.dart';

class _CountingFirestore extends TransactionFirestoreClient {
  int sessionReads = 0;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    if (sourceTag == 'followed_topics.load') sessionReads++;
    return super.getById(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }
}

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

  late _CountingFirestore firestore;
  late SettingsLocalDataSource settings;
  late LayoutPrefsStore layout;

  setUp(() {
    firestore = _CountingFirestore();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    layout = LayoutPrefsStore(settings, firestore);
    getIt.registerSingleton<FollowedTopicsStore>(FollowedTopicsStore(settings, firestore));
    getIt.registerSingleton<LayoutPrefsStore>(layout);
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  void followPastelAndDreamy() {
    firestore.docs['usersv2/u1/private'] = <String, Map<String, dynamic>>{
      'session': <String, dynamic>{
        'followedTopics': <String>['category:Pastel', 'mood:dreamy'],
      },
    };
  }

  testWidgets('a guest sees no Following row', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();

    await tester.pumpWidget(_app(const FollowingTopicsRow()));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsNothing);
  });

  testWidgets('a signed-in user with no topics sees no Following row', (tester) async {
    app_state.prismUser = profileUser();

    await tester.pumpWidget(_app(const FollowingTopicsRow()));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsNothing);
  });

  testWidgets('the Following row is hidden when the layout setting turns it off', (tester) async {
    app_state.prismUser = profileUser();
    followPastelAndDreamy();
    await layout.update(layout.value.copyWith(followingRow: false));

    await tester.pumpWidget(_app(const FollowingTopicsRow()));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsNothing);
    expect(find.text('Pastel'), findsNothing);
  });

  testWidgets('a signed-in user sees the Following header and the chips in follow order', (tester) async {
    app_state.prismUser = profileUser();
    followPastelAndDreamy();

    await tester.pumpWidget(_app(const FollowingTopicsRow()));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Pastel'), findsOneWidget);
    expect(find.text('Dreamy'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pastel')).dx, lessThan(tester.getTopLeft(find.text('Dreamy')).dx));
  });

  testWidgets('resume refreshes mounted rows once and disposed rows stop observing', (tester) async {
    app_state.prismUser = profileUser();
    followPastelAndDreamy();
    await tester.pumpWidget(_app(const FollowingTopicsRow()));
    await tester.pumpAndSettle();
    expect(firestore.sessionReads, 1);

    firestore.docs['usersv2/u1/private']!['session']!['followedTopics'] = <String>['mood:dreamy'];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(firestore.sessionReads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(firestore.sessionReads, 2);
    expect(find.text('Pastel'), findsNothing);
    expect(find.text('Dreamy'), findsOneWidget);

    await tester.pumpWidget(_app(const SizedBox.shrink()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(firestore.sessionReads, 2, reason: 'a disposed row must not refresh');

    await tester.pumpWidget(_app(const FollowingTopicsRow()));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(firestore.sessionReads, 3, reason: 'remounting must leave only one observer');
  });

  testWidgets('a chip with new walls says so in its semantics label, and a chip without news does not', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    app_state.prismUser = profileUser();
    followPastelAndDreamy();
    // The user last saw Pastel at 1000 ms. The Prism news says a wall landed at 2000 ms.
    await settings.set('followed_topics.seen.u1.category:Pastel', 1000);
    firestore.docs['topicNews'] = <String, Map<String, dynamic>>{
      'current': <String, dynamic>{
        'latest': <String, int>{'category:Pastel': 2000},
      },
    };

    await tester.pumpWidget(_app(const FollowingTopicsRow()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Pastel, new wallpapers'), findsOneWidget);
    expect(find.bySemanticsLabel('Dreamy'), findsOneWidget);
    expect(find.bySemanticsLabel('Dreamy, new wallpapers'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the large text setting does not overflow the row', (tester) async {
    app_state.prismUser = profileUser();
    followPastelAndDreamy();

    await tester.pumpWidget(_app(const FollowingTopicsRow(), textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.text('Pastel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
