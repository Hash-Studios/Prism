import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/creator_stats/biz/bloc/creator_stats_bloc.j.dart';
import 'package:Prism/features/creator_stats/data/creator_stats_repository_impl.dart';
import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/creator_stats/domain/get_creator_stats.dart';
import 'package:Prism/features/creator_stats/views/pages/creator_stats_page.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_copy.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../support/fake_app_analytics.dart';

class MockStatsBloc extends MockBloc<CreatorStatsEvent, CreatorStatsState> implements CreatorStatsBloc {}

class MockGetStats extends Mock implements GetCreatorStats {}

class MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

Map<String, Object?> fixture({bool empty = false}) {
  final start = DateTime.utc(2026, 8, 31);
  final weeks = List.generate(
    8,
    (i) => <String, Object?>{
      'week': '2026-W${36 + i}',
      'start': start.add(Duration(days: i * 7)).toIso8601String(),
      'endExclusive': start.add(Duration(days: (i + 1) * 7)).toIso8601String(),
      'metrics': {for (final m in StatsMetric.values) m.name: i == 0 ? null : i},
    },
  );
  final totals = {for (final m in StatsMetric.values) m.name: 10};
  return {
    'schemaVersion': 1,
    'timezone': 'UTC',
    'generatedAt': '2026-10-21T12:00:00Z',
    'asOf': '2026-10-21T12:00:00Z',
    'approvedWallCount': empty ? 0 : 1,
    'totals': totals,
    'coverage': {
      for (final m in StatsMetric.values)
        m.name: {'weeklyFrom': null, 'totalBasis': 'currentMembership', 'totalFrom': null},
    },
    'weeks': weeks,
    'walls': empty
        ? []
        : [
            {'wallId': 'one', 'title': 'Blue sky', 'thumbnailUrl': '', 'totals': totals, 'weeks': weeks},
          ],
  };
}

void main() {
  late FakeAppAnalytics analytics;
  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });
  test('creator deep link and weekly inbox target the signed-in dashboard', () async {
    final action = const DeepLinkParser().parse(Uri.parse('prism://creator-stats'));
    expect(await const DeepLinkNavigation().mapActionToRoute(action), isA<CreatorStatsRoute>());
    final inboxAction = await const NotificationRouteMapper().actionFromPayload({
      'route': 'creator_stats',
      'url': 'prism://creator-stats',
    }, sourceTag: 'test');
    final route = await const DeepLinkNavigation().mapActionToRoute(inboxAction!);
    expect(route, isA<CreatorStatsRoute>().having((r) => r.args?.source, 'source', 'inbox'));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      localizedNotificationCopyData(
        'creatorStatsWeekly',
        {'week': '2026-W43'},
        fallbackTitle: '',
        fallbackBody: '',
        l10n: l10n,
      ),
      (title: 'Your walls this week', body: 'See how your walls did in 2026-W43.'),
    );
  });
  test('parsing preserves null and zero separately', () {
    final raw = fixture();
    final weeks = raw['weeks']! as List;
    (weeks[1] as Map)['metrics'] = {for (final m in StatsMetric.values) m.name: 0};
    final data = parseCreatorStats(raw);
    expect(data.weeks.first.metrics[StatsMetric.views], isNull);
    expect(data.weeks[1].metrics[StatsMetric.views], 0);
    expect(data.coverage[StatsMetric.views]!.weeklyFrom, isNull);
  });
  test('rejects incomplete and unordered history', () {
    final raw = fixture();
    raw['weeks'] = (raw['weeks']! as List).reversed.toList();
    expect(() => parseCreatorStats(raw), throwsFormatException);
    raw['weeks'] = [];
    expect(() => parseCreatorStats(raw), throwsFormatException);
  });
  test('ranks by selected current-week metric with unavailable walls last', () {
    final raw = fixture();
    final original = (raw['walls']! as List).single as Map<String, Object?>;
    final weeks = original['weeks']! as List;
    final unknownWeeks = [
      ...weeks.take(7),
      {
        ...weeks.last as Map,
        'metrics': {for (final m in StatsMetric.values) m.name: null},
      },
    ];
    raw['approvedWallCount'] = 3;
    raw['walls'] = [
      original,
      {
        ...original,
        'wallId': 'zero',
        'weeks': [
          ...weeks.take(7),
          {
            ...weeks.last as Map,
            'metrics': {for (final m in StatsMetric.values) m.name: 0},
          },
        ],
      },
      {...original, 'wallId': 'unknown', 'weeks': unknownWeeks},
    ];
    expect(parseCreatorStats(raw).ranked(StatsMetric.saves).map((w) => w.wallId), ['one', 'zero', 'unknown']);
  });
  test('malformed callable payload reports a format failure', () {
    expect(() => parseCreatorStats(null), throwsFormatException);
    final raw = fixture();
    raw['totals'] = {'views': -1};
    expect(() => parseCreatorStats(raw), throwsFormatException);
  });
  blocTest<CreatorStatsBloc, CreatorStatsState>(
    'callable failure is retryable',
    build: () {
      final usecase = MockGetStats();
      when(() => usecase()).thenThrow(Exception('offline'));
      return CreatorStatsBloc(usecase);
    },
    act: (bloc) => bloc.add(const CreatorStatsEvent.load()),
    expect: () => [const CreatorStatsState(loading: true), const CreatorStatsState(failed: true)],
  );
  blocTest<CreatorStatsBloc, CreatorStatsState>(
    'loads through the use case',
    build: () {
      final usecase = MockGetStats();
      when(() => usecase()).thenAnswer((_) async => parseCreatorStats(fixture()));
      return CreatorStatsBloc(usecase);
    },
    act: (bloc) => bloc.add(const CreatorStatsEvent.load()),
    expect: () => [
      isA<CreatorStatsState>().having((s) => s.loading, 'loading', true),
      isA<CreatorStatsState>().having((s) => s.data?.approvedWallCount, 'walls', 1),
    ],
  );
  Future<MockStatsBloc> pump(WidgetTester tester, CreatorStatsState state, {double scale = 1}) async {
    final bloc = MockStatsBloc();
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: BlocProvider<CreatorStatsBloc>.value(value: bloc, child: const CreatorStatsView()),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  testWidgets('account changes discard visible and in-flight stats from the previous creator', (tester) async {
    final sessions = StreamController<SessionState>.broadcast();
    final session = MockSessionBloc();
    SessionState signedIn(String uid) => SessionState(
      status: LoadStatus.success,
      session: SessionEntity(userId: uid, loggedIn: true, premium: false, subscriptionTier: 'free'),
    );
    whenListen(session, sessions.stream, initialState: signedIn('alice'));
    final first = Completer<CreatorStats>();
    final second = Completer<CreatorStats>();
    final usecase = MockGetStats();
    var calls = 0;
    when(() => usecase()).thenAnswer((_) => calls++ == 0 ? first.future : second.future);
    getIt.registerFactory<CreatorStatsBloc>(() => CreatorStatsBloc(usecase));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SessionBloc>.value(value: session, child: const CreatorStatsPage()),
      ),
    );
    await tester.pump();
    sessions.add(signedIn('bob'));
    await tester.pump();
    await tester.pump();
    first.complete(parseCreatorStats(fixture()));
    await tester.pump();
    expect(find.text('Blue sky'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    second.complete(parseCreatorStats(fixture(empty: true)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Upload a wallpaper'), findsOneWidget);
    sessions.add(SessionState.initial());
    await tester.pump();
    await tester.pump();
    expect(find.text('Upload a wallpaper'), findsNothing);
    expect(find.textContaining('Sign in'), findsWidgets);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await sessions.close();
  });
  testWidgets('loading and error offer clear states and retry', (tester) async {
    await pump(tester, const CreatorStatsState(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final bloc = await pump(tester, const CreatorStatsState(failed: true));
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const CreatorStatsEvent.load())).called(1);
  });
  testWidgets('empty state includes upload entry at large text', (tester) async {
    await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture(empty: true))), scale: 2);
    expect(find.text('Upload a wallpaper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('metric switch dispatches and tracks typed event', (tester) async {
    final bloc = await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())));
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip, 'Saves'), 300);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Saves'));
    verify(() => bloc.add(const CreatorStatsEvent.select(StatsMetric.saves))).called(1);
    expect(analytics.events.single.eventName, 'creator_stats_metric_switched');
  });
  testWidgets('loaded dashboard and chart adapt to large text', (tester) async {
    await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())), scale: 2);
    await tester.scrollUntilVisible(find.byType(StatsChart), 300);
    await tester.ensureVisible(find.byType(StatsChart));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('all eight weekly chart values are visible at narrow width and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = parseCreatorStats(fixture());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StatsChart(weeks: data.weeks, metric: StatsMetric.views),
            ),
          ),
        ),
      ),
    );
    for (final label in [
      'Week of Aug 31, 2026: Unavailable',
      'Week of Sep 7, 2026: 1',
      'Week of Sep 14, 2026: 2',
      'Week of Sep 21, 2026: 3',
      'Week of Sep 28, 2026: 4',
      'Week of Oct 5, 2026: 5',
      'Week of Oct 12, 2026: 6',
      'Week of Oct 19, 2026: 7',
    ]) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      await tester.ensureVisible(text);
      expect(text.hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('wall detail uses response and chart has all eight semantic values', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())));
    await tester.scrollUntilVisible(find.text('Blue sky'), 300);
    await tester.ensureVisible(find.text('Blue sky'));
    await tester.pump();
    await tester.tap(find.text('Blue sky'));
    await tester.pumpAndSettle();
    expect(find.byType(WallStatsPage), findsOneWidget);
    expect(analytics.events.single.eventName, 'creator_wall_stats_opened');
    final chart = find.bySemanticsLabel(RegExp('Views, eight weeks.*Unavailable'));
    expect(chart, findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
