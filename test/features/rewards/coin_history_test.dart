import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/rewards/data/coin_history_repository.dart';
import 'package:Prism/features/rewards/views/pages/coin_history_page.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';

class _DelayedFirestore extends FakeFirestoreClient {
  final List<Completer<List<FakeDocRow>>> pending = <Completer<List<FakeDocRow>>>[];
  final Map<String, Future<List<FakeDocRow>>> _inflight = <String, Future<List<FakeDocRow>>>{};

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) async {
    querySpecs.add(spec);
    final String key = spec.filtersHash;
    final Future<List<FakeDocRow>>? inflight = _inflight[key];
    if (inflight != null) {
      return (await inflight).map((row) => map(row.data, row.id)).toList();
    }
    final request = Completer<List<FakeDocRow>>();
    pending.add(request);
    _inflight[key] = request.future;
    try {
      return (await request.future).map((row) => map(row.data, row.id)).toList();
    } finally {
      if (identical(_inflight[key], request.future)) _inflight.remove(key);
    }
  }
}

class _HistorySession extends Fake implements SessionRepository {
  _HistorySession(this.currentUser);

  @override
  PrismUsersV2 currentUser;
  final changes = StreamController<PrismUsersV2>.broadcast(sync: true);

  @override
  Stream<PrismUsersV2> watchCurrentUser() => changes.stream;
}

FakeDocRow _row(int i, {String action = 'wallpaperDownload', int delta = -5, String description = ''}) => (
  id: 'tx-$i',
  data: <String, dynamic>{
    'userId': 'user-1',
    'action': action,
    'delta': delta,
    'balanceBefore': 100 - delta,
    'balanceAfter': 100,
    'description': description,
    'createdAt': DateTime.utc(2026, 5).subtract(Duration(hours: i)),
  },
);

void main() {
  late FakeFirestoreClient firestore;

  setUp(() {
    firestore = FakeFirestoreClient();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  group('CoinHistoryRepository', () {
    test('the delayed client shares an identical in-flight query but not a settled one', () async {
      final delayed = _DelayedFirestore();
      final repository = CoinHistoryRepository(client: delayed);
      final first = repository.fetchPage();
      final shared = repository.fetchPage();
      expect(delayed.pending, hasLength(1));
      delayed.pending[0].complete(<FakeDocRow>[_row(0)]);
      expect((await first).items.single.id, 'tx-0');
      expect((await shared).items.single.id, 'tx-0');
      final fresh = repository.fetchPage();
      expect(delayed.pending, hasLength(2));
      delayed.pending[1].complete(<FakeDocRow>[_row(1)]);
      expect((await fresh).items.single.id, 'tx-1');
    });

    test('reads the newest page for the user with the history source tag', () async {
      firestore.onQuery = (_) => <FakeDocRow>[_row(0), _row(1)];

      final batch = await CoinHistoryRepository(client: firestore).fetchPage();

      final FirestoreQuerySpec spec = firestore.querySpecs.single;
      expect(spec.collection, 'coinTransactions');
      expect(spec.sourceTag, 'coin_history.page');
      expect(spec.limit, 40);
      expect(spec.startAfterDocId, isNull);
      expect(spec.filters.single.field, 'userId');
      expect(spec.filters.single.value, 'user-1');
      expect(spec.orderBy.single.field, 'createdAt');
      expect(spec.orderBy.single.descending, isTrue);
      expect(batch.items.map((e) => e.id), <String>['tx-0', 'tx-1']);
      expect(batch.hasMore, isFalse);
    });

    test('a full page has more, and the next page starts after the last row', () async {
      firestore.onQuery = (spec) =>
          spec.startAfterDocId == null ? <FakeDocRow>[for (int i = 0; i < 40; i++) _row(i)] : <FakeDocRow>[_row(40)];
      final repository = CoinHistoryRepository(client: firestore);

      final first = await repository.fetchPage();
      expect(first.hasMore, isTrue);
      final second = await repository.fetchPage(startAfterDocId: first.items.last.id);

      expect(firestore.querySpecs.last.startAfterDocId, 'tx-39');
      expect(second.items.single.id, 'tx-40');
      expect(second.hasMore, isFalse);
    });
  });

  group('zero-delta receipts', () {
    test('the repository hides them but keeps the cursor on the last row read', () async {
      firestore.onQuery = (_) => <FakeDocRow>[_row(0), _row(1, delta: 0), _row(2, delta: 0)];

      final batch = await CoinHistoryRepository(client: firestore).fetchPage();

      expect(batch.items.map((e) => e.id), <String>['tx-0']);
      expect(batch.cursor, 'tx-2');
    });

    testWidgets('the page does not list them and pages from the raw cursor', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      getIt.registerSingleton<FirestoreClient>(firestore);
      firestore.onQuery = (spec) => spec.startAfterDocId == null
          ? <FakeDocRow>[_row(0, delta: 8, action: 'dailyLogin'), for (int i = 1; i < 40; i++) _row(i, delta: 0)]
          : <FakeDocRow>[_row(40, delta: -10)];

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CoinHistoryPage(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('+8'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      await tester.tap(find.text('Show more'));
      await tester.pump();
      await tester.pump();

      expect(firestore.querySpecs.last.startAfterDocId, 'tx-39');
      expect(find.text('-10'), findsOneWidget);
    });
  });

  group('pages that show nothing', () {
    testWidgets('a pull keeps reading while every row is hidden, up to five pages', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      getIt.registerSingleton<FirestoreClient>(firestore);
      int page(String? cursor) => cursor == null ? 0 : int.parse(cursor.substring(3)) ~/ 40 + 1;
      firestore.onQuery = (spec) {
        final int p = page(spec.startAfterDocId);
        return <FakeDocRow>[for (int i = p * 40; i < p * 40 + 40; i++) _row(i, delta: p == 6 && i == p * 40 ? -10 : 0)];
      };

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CoinHistoryPage(),
        ),
      );
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }

      expect(firestore.querySpecs, hasLength(5));
      expect(find.text('No coin activity yet.'), findsNothing);
      expect(find.text('Show more'), findsOneWidget);

      await tester.tap(find.text('Show more'));
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }

      expect(firestore.querySpecs, hasLength(7));
      expect(find.text('-10'), findsOneWidget);
    });
  });

  group('CoinHistoryPage', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      getIt.registerSingleton<FirestoreClient>(firestore);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CoinHistoryPage(),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a refresh during an in-flight newest query waits for a fresh snapshot', (tester) async {
      final delayed = _DelayedFirestore();
      firestore = delayed;
      await pumpPage(tester);
      CoinsService.instance.balanceNotifier.value++;
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();

      delayed.pending[0].complete(<FakeDocRow>[_row(0)]);
      await tester.pump();
      await tester.pump();

      expect(find.text('-5'), findsNothing);
      expect(delayed.pending, hasLength(2));
      delayed.pending[1].complete(<FakeDocRow>[_row(1, delta: -9), _row(0)]);
      await tester.pump();
      await tester.pump();

      expect(find.text('-9'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('retained history refreshes newest rows and keeps the selected filter', (tester) async {
      List<FakeDocRow> ledger = <FakeDocRow>[_row(0, delta: -2), _row(1, delta: 5)];
      firestore.onQuery = (_) => ledger;
      await pumpPage(tester);
      final state = tester.state(find.byType(CoinHistoryPage));
      await tester.tap(find.widgetWithText(FilterChip, 'Spent'));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(navigator.push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Wheel')))));
      await tester.pumpAndSettle();
      ledger = <FakeDocRow>[
        (
          id: 'spin',
          data: <String, dynamic>{
            ..._row(2, action: 'spinWheel', delta: -9).data,
            'balanceAfter': 9,
          },
        ),
        ...ledger,
      ];
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      await tester.pump();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(CoinHistoryPage)), same(state));
      expect(firestore.querySpecs, hasLength(2));
      expect(firestore.querySpecs.last.startAfterDocId, isNull);
      expect(find.text('-9'), findsOneWidget);
      expect(find.text('Balance 9'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);
      expect(find.text('+5'), findsNothing);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Spent')).selected, isTrue);
    });

    testWidgets('refresh resets pagination and a late older page cannot append or hide a newer refresh', (
      tester,
    ) async {
      final delayed = _DelayedFirestore();
      firestore = delayed;
      await pumpPage(tester);
      delayed.pending[0].complete(<FakeDocRow>[_row(0), for (int i = 1; i < 40; i++) _row(i, delta: 0)]);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Show more'));
      await tester.pump();
      expect(delayed.querySpecs[1].startAfterDocId, 'tx-39');

      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      expect(delayed.pending, hasLength(2));
      delayed.pending[1].complete(<FakeDocRow>[_row(40, delta: -7)]);
      await tester.pump();
      await tester.pump();
      expect(delayed.querySpecs[2].startAfterDocId, isNull);
      expect(find.text('-7'), findsNothing);
      CoinsService.instance.balanceNotifier.value++;
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      expect(delayed.pending, hasLength(3));
      delayed.pending[2].completeError(StateError('superseded refresh failed'));
      await tester.pump();
      await tester.pump();
      expect(delayed.querySpecs[3].startAfterDocId, isNull);
      delayed.pending[3].complete(<FakeDocRow>[_row(80, delta: -9), _row(0)]);
      await tester.pump();
      await tester.pump();

      expect(find.text('-9'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('-7'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('refresh waits for filtered auto-pagination and resumes it from the newest page', (tester) async {
      final delayed = _DelayedFirestore();
      firestore = delayed;
      await pumpPage(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Spent'));
      delayed.pending[0].complete(<FakeDocRow>[for (int i = 0; i < 40; i++) _row(i, delta: 8)]);
      await tester.pump();
      await tester.pump();
      expect(delayed.querySpecs[1].startAfterDocId, 'tx-39');
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      delayed.pending[1].complete(<FakeDocRow>[_row(40, delta: -7)]);
      await tester.pump();
      await tester.pump();
      expect(delayed.querySpecs[2].startAfterDocId, isNull);
      expect(find.text('-7'), findsNothing);
      delayed.pending[2].complete(<FakeDocRow>[for (int i = 80; i < 120; i++) _row(i, delta: 8)]);
      await tester.pump();
      await tester.pump();
      expect(delayed.querySpecs[3].startAfterDocId, 'tx-119');
      delayed.pending[3].complete(<FakeDocRow>[_row(120, delta: -9)]);
      await tester.pump();
      await tester.pump();

      expect(find.text('-9'), findsOneWidget);
      expect(find.text('-7'), findsNothing);
      expect(find.text('+8'), findsNothing);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Spent')).selected, isTrue);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('a queued refresh runs after an initial failure and exposes only its own retry', (tester) async {
      final delayed = _DelayedFirestore();
      firestore = delayed;
      await pumpPage(tester);
      CoinsService.instance.balanceNotifier.value++;
      delayed.pending[0].completeError(StateError('superseded initial read failed'));
      await tester.pump();
      await tester.pump();
      expect(delayed.pending, hasLength(2));
      expect(find.text('Try again'), findsNothing);
      delayed.pending[1].completeError(StateError('latest refresh failed'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(delayed.querySpecs[2].startAfterDocId, isNull);
      delayed.pending[2].complete(<FakeDocRow>[_row(1, delta: -9)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('-9'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('failed refresh keeps rows and retries the newest page instead of appending', (tester) async {
      firestore.onQuery = (_) => <FakeDocRow>[_row(0), for (int i = 1; i < 40; i++) _row(i, delta: 0)];
      await pumpPage(tester);
      firestore.queryError = StateError('offline');
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      await tester.pump();
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      firestore.queryError = null;
      firestore.onQuery = (_) => <FakeDocRow>[_row(50, delta: -9), _row(0)];
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(firestore.querySpecs.last.startAfterDocId, isNull);
      expect(find.text('-9'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('account switch clears old rows and rejects late previous-owner responses', (tester) async {
      final delayed = _DelayedFirestore();
      firestore = delayed;
      await pumpPage(tester);
      delayed.pending[0].complete(<FakeDocRow>[_row(0)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('-5'), findsOneWidget);
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      app_state.prismUser = app_constants.createGuestPrismUser()
        ..id = 'user-2'
        ..loggedIn = true;
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      expect(find.text('-5'), findsNothing);
      expect(delayed.querySpecs.last.filters.single.value, 'user-2');
      expect(delayed.querySpecs.last.startAfterDocId, isNull);
      delayed.pending[2].complete(<FakeDocRow>[_row(99, delta: -3)]);
      await tester.pump();
      await tester.pump();
      delayed.pending[1].complete(<FakeDocRow>[_row(1, delta: -7)]);
      await tester.pump();
      expect(find.text('-3'), findsOneWidget);
      expect(find.text('-7'), findsNothing);

      app_state.prismUser = app_constants.createGuestPrismUser();
      CoinsService.instance.balanceNotifier.value++;
      await tester.pump();
      expect(find.text('-3'), findsNothing);
      expect(delayed.querySpecs, hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
      CoinsService.instance.balanceNotifier.value++;
      expect(tester.takeException(), isNull);
    });

    testWidgets('session changes clear private rows even when balance does not change', (tester) async {
      final session = _HistorySession(app_state.prismUser);
      getIt.registerSingleton<SessionRepository>(session);
      firestore.onQuery = (_) => <FakeDocRow>[_row(0)];
      await pumpPage(tester);
      expect(find.text('-5'), findsOneWidget);
      final int balance = CoinsService.instance.balanceNotifier.value;
      session.currentUser = app_constants.createGuestPrismUser();
      session.changes.add(session.currentUser);
      await tester.pump();
      expect(find.text('-5'), findsNothing);
      expect(firestore.querySpecs, hasLength(1));
      firestore.onQuery = (_) => <FakeDocRow>[_row(2, delta: -3)];
      session.currentUser = app_constants.createGuestPrismUser()
        ..id = 'user-2'
        ..loggedIn = true;
      session.changes.add(session.currentUser);
      await tester.pump();
      await tester.pump();
      expect(CoinsService.instance.balanceNotifier.value, balance);
      expect(firestore.querySpecs.last.filters.single.value, 'user-2');
      expect(firestore.querySpecs.last.startAfterDocId, isNull);
      expect(find.text('-3'), findsOneWidget);
      expect(find.text('-5'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.changes.close();
      await getIt.unregister<SessionRepository>();
    });

    testWidgets('returning to an owner waits for its old read without blocking another owner', (tester) async {
      final delayed = _DelayedFirestore();
      firestore = delayed;
      final session = _HistorySession(app_state.prismUser);
      getIt.registerSingleton<SessionRepository>(session);
      await pumpPage(tester);
      CoinsService.instance.balanceNotifier.value++;
      session.currentUser = app_constants.createGuestPrismUser()
        ..id = 'user-2'
        ..loggedIn = true;
      session.changes.add(session.currentUser);
      await tester.pump();
      expect(delayed.querySpecs[1].filters.single.value, 'user-2');
      session.currentUser = app_constants.createGuestPrismUser()
        ..id = 'user-1'
        ..loggedIn = true;
      session.changes.add(session.currentUser);
      await tester.pump();
      expect(delayed.pending, hasLength(2));
      delayed.pending[0].complete(<FakeDocRow>[_row(0, delta: -7)]);
      await tester.pump();
      await tester.pump();
      expect(delayed.querySpecs[2].filters.single.value, 'user-1');
      expect(find.text('-7'), findsNothing);
      delayed.pending[2].complete(<FakeDocRow>[_row(1, delta: -9)]);
      await tester.pump();
      await tester.pump();
      delayed.pending[1].complete(<FakeDocRow>[_row(2, delta: -3)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('-9'), findsOneWidget);
      expect(find.text('-3'), findsNothing);
      expect(delayed.pending, hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
      await session.changes.close();
      await getIt.unregister<SessionRepository>();
    });

    for (final bool dispose in <bool>[false, true]) {
      testWidgets('${dispose ? 'disposal' : 'logout'} cancels a queued refresh after the active read fails', (
        tester,
      ) async {
        final delayed = _DelayedFirestore();
        firestore = delayed;
        await pumpPage(tester);
        delayed.pending[0].complete(<FakeDocRow>[_row(0)]);
        await tester.pump();
        await tester.pump();
        expect(find.text('-5'), findsOneWidget);
        CoinsService.instance.balanceNotifier.value++;
        CoinsService.instance.balanceNotifier.value++;
        await tester.pump();
        if (dispose) {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          app_state.prismUser = app_constants.createGuestPrismUser();
          CoinsService.instance.balanceNotifier.value++;
          await tester.pump();
        }
        delayed.pending[1].completeError(StateError('read failed after leaving'));
        await tester.pump();
        await tester.pump();
        expect(find.text('-5'), findsNothing);
        expect(find.text('Try again'), findsNothing);
        expect(delayed.pending, hasLength(2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('rows show label, description, signed amount and the balance after', (tester) async {
      final analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
      firestore.onQuery = (_) => <FakeDocRow>[
        _row(0, description: 'Sunset over the bay'),
        _row(1, action: 'dailyLogin', delta: 8, description: 'Daily login reward (+8)'),
      ];

      await pumpPage(tester);

      expect(find.text('Coin history'), findsOneWidget);
      expect(find.text('Wallpaper download'), findsOneWidget);
      expect(find.text('Sunset over the bay'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+8'), findsOneWidget);
      expect(find.text('Balance 100'), findsNWidgets(2));
      expect(analytics.events.whereType<CoinHistoryOpenedEvent>(), hasLength(1));
    });

    for (final reason in <String>['ai_generation_reserved', 'ai_generation']) {
      testWidgets('AI charge hides internal $reason copy without changing amounts', (tester) async {
        firestore.onQuery = (_) => <FakeDocRow>[
          (
            id: 'ai-charge',
            data: <String, dynamic>{
              ..._row(0, action: 'aiGeneration', delta: -10, description: reason).data,
              'reason': reason,
              'balanceBefore': 21,
              'balanceAfter': 11,
            },
          ),
          _row(1, action: 'aiGeneration', delta: -10, description: 'Moonlit mountains'),
        ];

        await pumpPage(tester);

        expect(find.text('AI wallpaper'), findsNWidgets(2));
        expect(find.text(reason), findsNothing);
        expect(find.text('Moonlit mountains'), findsOneWidget);
        expect(find.text('-10'), findsNWidgets(2));
        expect(find.text('Balance 11'), findsOneWidget);
      });
    }

    for (final sample in <({String action, String reason, String label})>[
      (action: 'premiumPreview24h', reason: 'premium_preview_unlock_24h', label: 'Collection preview, 24 h'),
      (action: 'wallpaperDownload', reason: 'content_E3EI', label: 'Wallpaper download'),
      (action: 'wallpaperDownload', reason: 'wallpaperDownload', label: 'Wallpaper download'),
      (action: 'premiumWallpaperDownload', reason: 'content_E3EI', label: 'Premium wallpaper'),
    ]) {
      testWidgets('Spent hides ${sample.action} reason ${sample.reason} but keeps human copy', (tester) async {
        final semantics = tester.ensureSemantics();
        firestore.onQuery = (_) => <FakeDocRow>[
          _row(0, action: sample.action, description: sample.reason),
          _row(1, action: sample.action, description: 'Sunset over the bay'),
          _row(2, action: 'dailyLogin', delta: 8),
        ];

        await pumpPage(tester);
        await tester.tap(find.widgetWithText(FilterChip, 'Spent'));
        await tester.pump();

        expect(find.text(sample.label), findsNWidgets(2));
        expect(find.text(sample.reason), findsNothing);
        expect(find.bySemanticsLabel(RegExp('.*${sample.reason}.*')), findsNothing);
        expect(find.text('Sunset over the bay'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('.*Sunset over the bay.*')), findsOneWidget);
        expect(find.text('-5'), findsNWidgets(2));
        expect(find.text('Balance 100'), findsNWidgets(2));
        expect(find.text('+8'), findsNothing);
        semantics.dispose();
      });
    }

    testWidgets('reason-like human descriptions and unrelated actions stay intact', (tester) async {
      firestore.onQuery = (_) => <FakeDocRow>[
        _row(0, description: 'content_my favourite wallpaper'),
        _row(1, description: 'premium_preview_unlock_24h'),
        _row(2, action: 'premiumPreview24h', description: 'content_E3EI'),
        _row(3, description: 'wallpaperDownload memories'),
      ];

      await pumpPage(tester);

      for (final description in <String>[
        'content_my favourite wallpaper',
        'premium_preview_unlock_24h',
        'content_E3EI',
        'wallpaperDownload memories',
      ]) {
        expect(find.text(description), findsOneWidget);
      }
      expect(find.text('Wallpaper download'), findsNWidgets(3));
    });

    testWidgets('filter chips narrow the loaded rows', (tester) async {
      firestore.onQuery = (_) => <FakeDocRow>[
        _row(0),
        _row(1, action: 'dailyLogin', delta: 8),
        _row(2, action: 'refund', delta: 10),
      ];
      await pumpPage(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Earned'));
      await tester.pump();
      expect(find.text('+8'), findsOneWidget);
      expect(find.text('+10'), findsNothing);
      expect(find.text('-5'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Spent'));
      await tester.pump();
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+8'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Refunds'));
      await tester.pump();
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('-5'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Refunds'));
      await tester.pump();
      expect(find.text('+8'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
    });

    testWidgets('Show more loads the next page after the last row', (tester) async {
      firestore.onQuery = (spec) => spec.startAfterDocId == null
          ? <FakeDocRow>[for (int i = 0; i < 40; i++) _row(i, delta: -1)]
          : <FakeDocRow>[_row(40, delta: -7)];
      await pumpPage(tester);
      expect(find.text('-7'), findsNothing);

      await tester.scrollUntilVisible(find.text('Show more'), 400, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Show more'));
      await tester.pump();
      await tester.pump();

      expect(firestore.querySpecs.last.startAfterDocId, 'tx-39');
      await tester.scrollUntilVisible(find.text('-7'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('-7'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('an empty ledger and a failed load have calm copy and Try again works', (tester) async {
      firestore.onQuery = (_) => const <FakeDocRow>[];
      await pumpPage(tester);
      expect(find.text('No coin activity yet.'), findsOneWidget);

      firestore.queryError = StateError('offline');
      firestore.onQuery = (_) => <FakeDocRow>[_row(0)];
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CoinHistoryPage(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't load your coin history."), findsOneWidget);

      firestore.queryError = null;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Wallpaper download'), findsOneWidget);
    });
  });
}
