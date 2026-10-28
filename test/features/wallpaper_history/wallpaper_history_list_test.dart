import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/wallpaper_history_list.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _MockStackRouter extends Mock implements StackRouter {}

final DateTime fixedNow = DateTime(2026, 10, 28, 15);

AppliedWallpaper item(String id, DateTime at, {String target = 'home', String? wallpaperId}) => AppliedWallpaper(
  id: id,
  source: 'prism',
  thumbnailUrl: '/missing.jpg',
  fullUrl: '/missing-$id.jpg',
  target: target,
  appliedAt: at,
  wallpaperId: wallpaperId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAppAnalytics analytics;
  late WallpaperHistoryStore store;
  WallpaperHistoryBloc? bloc;

  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    await initializeDateFormatting('en');
  });

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    store = WallpaperHistoryStore(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    await bloc?.close();
    AnalyticsRuntime.reset();
  });

  Future<void> recordAll(List<AppliedWallpaper> items) async {
    // Oldest first, so each record lands at the top of the list.
    for (final AppliedWallpaper wall in items.reversed) {
      await store.record(wall);
    }
  }

  Widget app({Widget? extra, StackRouter? router}) {
    Widget home = BlocProvider.value(
      value: bloc!,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            ?extra,
            Expanded(child: WallpaperHistoryList(now: () => fixedNow)),
          ],
        ),
      ),
    );
    if (router != null) {
      home = StackRouterScope(controller: router, stateHash: 0, child: home);
    }
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  Future<void> pumpList(WidgetTester tester, {Widget? extra, StackRouter? router}) async {
    bloc = WallpaperHistoryBloc(store)..add(const WallpaperHistoryEvent.started());
    await tester.pumpWidget(app(extra: extra, router: router));
    await tester.pump();
  }

  group('groupHistoryByDay', () {
    test('splits newest-first items into local days and keeps the order inside a day', () {
      final List<HistoryDay> groups = groupHistoryByDay(<AppliedWallpaper>[
        item('a', DateTime(2026, 10, 28, 14)),
        item('b', DateTime(2026, 10, 28, 9)),
        item('c', DateTime(2026, 10, 27, 22)),
        item('d', DateTime(2026, 10, 20, 10)),
      ]);

      expect(groups.map((g) => g.day), <DateTime>[
        DateTime(2026, 10, 28),
        DateTime(2026, 10, 27),
        DateTime(2026, 10, 20),
      ]);
      expect(groups[0].items.map((i) => i.id), <String>['a', 'b']);
      expect(groups[1].items.map((i) => i.id), <String>['c']);
      expect(groups[2].items.map((i) => i.id), <String>['d']);
    });

    test('an empty list gives no groups', () {
      expect(groupHistoryByDay(const <AppliedWallpaper>[]), isEmpty);
    });
  });

  group('historyDayLabel', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();

    test('same day is Today and the day before is Yesterday', () {
      expect(historyDayLabel(l10n, DateTime(2026, 10, 28), fixedNow), 'Today');
      expect(historyDayLabel(l10n, DateTime(2026, 10, 27), fixedNow), 'Yesterday');
    });

    test('the day before remains Yesterday across a daylight saving transition', () {
      expect(historyDayLabel(l10n, DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 'Yesterday');
    });

    test('a day this year shows the weekday and the month day', () {
      final DateTime day = DateTime(2026, 10, 20);
      expect(historyDayLabel(l10n, day, fixedNow), DateFormat.MMMEd('en').format(day));
      expect(historyDayLabel(l10n, day, fixedNow), 'Tue, Oct 20');
    });

    test('a day in a previous year also shows the year', () {
      final DateTime day = DateTime(2025, 12, 31);
      expect(historyDayLabel(l10n, day, fixedNow), DateFormat.yMMMEd('en').format(day));
      expect(historyDayLabel(l10n, day, fixedNow), 'Wed, Dec 31, 2025');
    });
  });

  testWidgets('an empty store shows the empty state and no tiles', (tester) async {
    await pumpList(tester);

    expect(find.text('No wallpapers yet'), findsOneWidget);
    expect(find.text('Browse wallpapers'), findsOneWidget);
    expect(find.byType(AppliedWallpaperTile), findsNothing);
  });

  testWidgets('refresh picks up a wallpaper recorded elsewhere while the history tab stays mounted', (tester) async {
    await pumpList(tester);
    expect(find.byType(AppliedWallpaperTile), findsNothing);

    await store.record(item('set-elsewhere', DateTime(2026, 10, 28, 14)));
    final Future<void> refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    await refresh;

    expect(find.byType(AppliedWallpaperTile), findsOneWidget);
  });

  testWidgets('refresh with unchanged history completes', (tester) async {
    await pumpList(tester);

    final Future<void> refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    await refresh;

    expect(bloc!.state.items, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('items are grouped under Today and their day label, not Yesterday', (tester) async {
    await recordAll(<AppliedWallpaper>[
      item('a', DateTime(2026, 10, 28, 14)),
      item('b', DateTime(2026, 10, 28, 9)),
      item('c', DateTime(2026, 10, 20, 10)),
    ]);
    await pumpList(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tue, Oct 20'), findsOneWidget);
    expect(find.text('Yesterday'), findsNothing);
    expect(find.byType(AppliedWallpaperTile), findsNWidgets(3));
  });

  testWidgets('each tile has a Set again button and tapping the first one tracks the event', (tester) async {
    await recordAll(<AppliedWallpaper>[
      item('a', DateTime(2026, 10, 28, 14)),
      item('b', DateTime(2026, 10, 28, 9)),
      item('c', DateTime(2026, 10, 20, 10)),
    ]);
    await pumpList(tester);

    expect(find.byTooltip('Set again'), findsNWidgets(3));
    await tester.tap(find.byTooltip('Set again').first);
    await tester.pump();

    final List<LibraryHistorySetAgainEvent> events = analytics.events.whereType<LibraryHistorySetAgainEvent>().toList();
    expect(events, hasLength(1));
    expect(events.single.provider, 'prism');
    expect(events.single.target, 'home');
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a prism tile opens its wallpaper detail', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    await recordAll(<AppliedWallpaper>[item('a', DateTime(2026, 10, 28, 14), wallpaperId: 'w1')]);
    await pumpList(tester, router: router);

    await tester.tapAt(tester.getTopLeft(find.byType(AppliedWallpaperTile).first) + const Offset(20, 20));
    await tester.pump();

    final VerificationResult result = verify(() => router.push(captureAny(that: isA<WallpaperDetailRoute>())));
    result.called(1);
    final WallpaperDetailRoute route = result.captured.single as WallpaperDetailRoute;
    expect(route.args!.wallId, 'w1');
    expect(route.args!.source, WallpaperSource.prism);
  });

  testWidgets('opening a history tile reloads history when its detail route returns', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    final Completer<Object?> routeResult = Completer<Object?>();
    await recordAll(<AppliedWallpaper>[item('a', DateTime(2026, 10, 28, 14), wallpaperId: 'w1')]);
    await pumpList(tester, router: router);
    when(() => router.push(any())).thenAnswer((_) => routeResult.future);

    await tester.tap(find.byType(AppliedWallpaperTile).first);
    await store.record(item('b', DateTime(2026, 10, 28, 15), wallpaperId: 'w2'));
    routeResult.complete(null);
    await tester.pump();

    expect(find.byType(AppliedWallpaperTile), findsNWidgets(2));
  });

  testWidgets('only the newest home tile shows the Current badge', (tester) async {
    await recordAll(<AppliedWallpaper>[
      item('new', DateTime(2026, 10, 28, 14)),
      item('old', DateTime(2026, 10, 20, 10)),
    ]);
    await pumpList(tester);

    expect(find.text('Current'), findsOneWidget);
  });

  testWidgets('a long press removes the tile and Undo restores it', (tester) async {
    await recordAll(<AppliedWallpaper>[item('a', DateTime(2026, 10, 28, 14)), item('b', DateTime(2026, 10, 28, 9))]);
    await pumpList(tester);

    await tester.longPress(find.byType(AppliedWallpaperTile).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AppliedWallpaperTile), findsOneWidget);
    expect(find.text('Removed from history'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AppliedWallpaperTile), findsNWidgets(2));
    expect(bloc!.state.items.map((i) => i.id), <String>['a', 'b']);
  });

  testWidgets('Undo restores the store after its history bloc closes', (tester) async {
    await recordAll(<AppliedWallpaper>[item('a', DateTime(2026, 10, 28, 14))]);
    await pumpList(tester);
    await tester.longPress(find.byType(AppliedWallpaperTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final SnackBarAction undo = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    await tester.runAsync(() => bloc!.close());
    expect(bloc!.isClosed, isTrue);
    await tester.runAsync(() async => undo.onPressed());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(store.items().map((i) => i.id), <String>['a']);
  });

  testWidgets('confirmClearHistory clears the list on confirm and tracks the count', (tester) async {
    await recordAll(<AppliedWallpaper>[
      item('a', DateTime(2026, 10, 28, 14)),
      item('b', DateTime(2026, 10, 20, 10)),
      item('c', DateTime(2026, 10, 19, 10)),
    ]);
    await pumpList(
      tester,
      extra: Builder(
        builder: (context) =>
            TextButton(onPressed: () => confirmClearHistory(context), child: const Text('Start clear')),
      ),
    );

    await tester.tap(find.text('Start clear'));
    await tester.pumpAndSettle();

    expect(find.text('Clear history?'), findsOneWidget);
    expect(find.text('This removes the list of wallpapers you set. Your wallpapers stay as they are.'), findsOneWidget);
    await tester.tap(find.text('Clear history'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(bloc!.state.items, isEmpty);
    expect(analytics.events.whereType<LibraryHistoryClearedEvent>().single.count, 3);
  });

  testWidgets('cancelling confirmClearHistory keeps the items and tracks nothing', (tester) async {
    await recordAll(<AppliedWallpaper>[item('a', DateTime(2026, 10, 28, 14))]);
    await pumpList(
      tester,
      extra: Builder(
        builder: (context) =>
            TextButton(onPressed: () => confirmClearHistory(context), child: const Text('Start clear')),
      ),
    );

    await tester.tap(find.text('Start clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(bloc!.state.items, hasLength(1));
    expect(analytics.events.whereType<LibraryHistoryClearedEvent>(), isEmpty);
  });

  testWidgets('the Current tile has a screen reader label with the time and a remove action', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await recordAll(<AppliedWallpaper>[item('a', DateTime(2026, 10, 28, 14)), item('b', DateTime(2026, 10, 20, 10))]);
    await pumpList(tester);

    final Finder tile = find.bySemanticsLabel(RegExp(r'^Current\. Home screen'));
    expect(tile, findsOneWidget);
    expect(find.bySemanticsLabel('Current. Home screen, set at 2:00 PM'), findsOneWidget);

    final SemanticsData data = tester.getSemantics(tile).getSemanticsData();
    expect(
      data.customSemanticsActionIds,
      contains(CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: 'Remove from history'))),
    );
    handle.dispose();
  });

  // Replaces the Set screen opener and records each request it receives.
  void stubSetScreen(List<SetScreenRequest> opened) {
    final original = SetWallpaperFlow.screenOpener;
    SetWallpaperFlow.screenOpener = (context, request) async {
      opened.add(request);
      return null;
    };
    addTearDown(() => SetWallpaperFlow.screenOpener = original);
  }

  // The set flow runs asynchronously; pump real time until the Set screen request arrives.
  Future<void> waitForSetScreen(WidgetTester tester, List<SetScreenRequest> opened) async {
    for (int i = 0; i < 80 && opened.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  testWidgets('Set again opens the Set screen as wallpaper_history even with a saved default', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set(PersistenceKeys.defaultApplyTarget, 'home');
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    addTearDown(() => getIt.unregister<SettingsLocalDataSource>());
    final List<SetScreenRequest> opened = <SetScreenRequest>[];
    stubSetScreen(opened);
    await recordAll(<AppliedWallpaper>[item('a', DateTime(2026, 10, 28, 14))]);
    await pumpList(tester);

    await tester.tap(find.byTooltip('Set again'));
    await tester.pump();
    await waitForSetScreen(tester, opened);

    expect(opened, hasLength(1));
    expect(opened.single.url, '/missing-a.jpg');
    expect(opened.single.thumbnailUrl, '/missing.jpg');
    expect(opened.single.onAdjust, isNotNull);
  });

  testWidgets('a set again Prism wall keeps its identity for preview and original consent', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'recent-owner'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    final List<SetScreenRequest> opened = <SetScreenRequest>[];
    stubSetScreen(opened);
    await recordAll(<AppliedWallpaper>[
      AppliedWallpaper(
        id: 'history-1',
        wallpaperId: 'prism-1',
        source: 'prism',
        fullUrl: 'https://example.com/original.jpg',
        thumbnailUrl: '/missing/preview.jpg',
        target: 'home',
        appliedAt: DateTime(2026, 10, 28, 14),
      ),
    ]);
    await pumpList(tester);

    await tester.tap(find.byTooltip('Set again'));
    await tester.pump();
    await waitForSetScreen(tester, opened);

    expect(opened, hasLength(1));
    expect(opened.single.wallpaperId, 'prism-1');
    expect(opened.single.wallpaperSource, WallpaperSource.prism);
    expect(opened.single.thumbnailUrl, '/missing/preview.jpg');
  });
}
