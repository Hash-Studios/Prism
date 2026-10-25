import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/rewards/data/coin_history_repository.dart';
import 'package:Prism/features/rewards/views/pages/coin_history_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';

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
