import 'dart:async';
import 'dart:ui' show Paragraph;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_fund/biz/bloc/creator_fund_bloc.j.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_repository.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:Prism/features/creator_stats/biz/bloc/creator_stats_bloc.j.dart';
import 'package:Prism/features/creator_stats/data/creator_stats_repository_impl.dart';
import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/creator_stats/domain/get_creator_stats.dart';
import 'package:Prism/features/creator_stats/domain/stats_period.dart';
import 'package:Prism/features/creator_stats/views/pages/creator_stats_page.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_copy.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Tips for [stats]: 2 tips and 35 coins in the last week, 1 tip and 25 coins on wall 'one'.
Map<String, Object?> tipsFixture(Map<String, Object?> stats) {
  final weeks = (stats['weeks']! as List).cast<Map<String, Object?>>();
  final last = weeks.length - 1;
  return {
    'count': 2,
    'coins': 35,
    'weeks': [
      for (var i = 0; i < weeks.length; i++)
        {'week': weeks[i]['week'], 'start': weeks[i]['start'], 'count': i == last ? 2 : 0, 'coins': i == last ? 35 : 0},
    ],
    'walls': [
      {'wallId': 'one', 'count': 1, 'coins': 25},
    ],
  };
}

class _OffFund implements CreatorFundRepository {
  @override
  Future<CreatorFundStatus> load() async => const CreatorFundOff(week: '2026-W46');
}

class _ParagraphBoundsCanvas extends TestRecordingCanvas {
  final bounds = <(double, Offset)>[];

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {
    bounds.add((paragraph.maxIntrinsicWidth, offset));
  }
}

Widget _withFund({required CreatorStatsBloc value, required Widget child}) => MultiBlocProvider(
  providers: [
    BlocProvider<CreatorStatsBloc>.value(value: value),
    BlocProvider<CreatorFundBloc>(create: (_) => CreatorFundBloc(_OffFund())..add(const CreatorFundEvent.load())),
  ],
  child: child,
);

void main() {
  setUpAll(() => registerFallbackValue(const CreatorStatsEvent.load()));
  late FakeAppAnalytics analytics;
  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    getIt.registerFactory<CreatorFundBloc>(() => CreatorFundBloc(_OffFund()));
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
    expect(parseCreatorStats(raw).ranked(StatsMetric.saves, StatsPeriod.thisWeek).map((w) => w.wallId), [
      'one',
      'zero',
      'unknown',
    ]);
  });
  test('malformed callable payload reports a format failure', () {
    expect(() => parseCreatorStats(null), throwsFormatException);
    final raw = fixture();
    raw['totals'] = {'views': -1};
    expect(() => parseCreatorStats(raw), throwsFormatException);
  });
  test('payload without tips parses as no tips', () {
    final stats = parseCreatorStats(fixture());
    expect(stats.tips.count, 0);
    expect(stats.tips.weeks, isEmpty);
  });
  test('parses tips per week and per wall', () {
    final raw = fixture();
    raw['tips'] = tipsFixture(raw);
    final stats = parseCreatorStats(raw);
    expect(stats.tips.count, 2);
    expect(stats.tips.coins, 35);
    expect(stats.tips.weeks, hasLength(8));
    expect(stats.tips.weeks.last.count, 2);
    expect(stats.tips.walls['one']!.coins, 25);
  });
  test('tip weeks must match the stats weeks and counts must not be negative', () {
    final badWeek = fixture();
    badWeek['tips'] = tipsFixture(badWeek);
    (((badWeek['tips']! as Map)['weeks'] as List).first as Map<String, Object?>)['week'] = '2026-W99';
    expect(() => parseCreatorStats(badWeek), throwsFormatException);

    final negative = fixture();
    negative['tips'] = tipsFixture(negative)..['count'] = -1;
    expect(() => parseCreatorStats(negative), throwsFormatException);
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
  Future<MockStatsBloc> pump(
    WidgetTester tester,
    CreatorStatsState state, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    final bloc = MockStatsBloc();
    when(() => bloc.state).thenReturn(state);
    final session = MockSessionBloc();
    whenListen(
      session,
      const Stream<SessionState>.empty(),
      initialState: const SessionState(
        status: LoadStatus.success,
        session: SessionEntity(userId: 'alice', loggedIn: true, premium: false, subscriptionTier: 'free'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: BlocProvider<SessionBloc>.value(value: session, child: child),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _withFund(
          value: bloc,
          child: const CreatorStatsView(ownerUid: 'alice'),
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
    expect(find.byType(PrismSkeleton), findsOneWidget);
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
  for (final nextOwner in ['bob', '']) {
    testWidgets('open wall detail hides its snapshot when owner becomes $nextOwner', (tester) async {
      final sessions = StreamController<SessionState>.broadcast();
      final session = MockSessionBloc();
      SessionState signedIn(String uid) => SessionState(
        status: LoadStatus.success,
        session: SessionEntity(userId: uid, loggedIn: true, premium: false, subscriptionTier: 'free'),
      );
      whenListen(session, sessions.stream, initialState: signedIn('alice'));
      final usecase = MockGetStats();
      when(() => usecase()).thenAnswer((_) async => parseCreatorStats(fixture()));
      getIt.registerFactory<CreatorStatsBloc>(() => CreatorStatsBloc(usecase));
      await tester.pumpWidget(
        BlocProvider<SessionBloc>.value(
          value: session,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CreatorStatsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Blue sky'), 300);
      await tester.tap(find.text('Blue sky'));
      await tester.pumpAndSettle();
      expect(find.byType(WallStatsPage), findsOneWidget);
      expect(find.text('Blue sky'), findsOneWidget);
      sessions.add(nextOwner.isEmpty ? SessionState.initial() : signedIn(nextOwner));
      await tester.pumpAndSettle();
      expect(find.text('Blue sky'), findsNothing);
      expect(find.byType(StatsChart), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await sessions.close();
    });
  }
  testWidgets('loading and error offer clear states and retry', (tester) async {
    await pump(tester, const CreatorStatsState(loading: true));
    expect(find.byType(PrismSkeleton), findsOneWidget);
    final bloc = await pump(tester, const CreatorStatsState(failed: true));
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const CreatorStatsEvent.load())).called(1);
  });
  for (final brightness in Brightness.values) {
    testWidgets('empty state keeps Glint clear of copy at large text in ${brightness.name} theme', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        CreatorStatsState(data: parseCreatorStats(fixture(empty: true))),
        scale: 2,
        brightness: brightness,
      );
      final title = find.text('Your first wall starts here');
      final upload = find.text('Upload a wallpaper');
      expect(Theme.of(tester.element(title)).brightness, brightness);
      final glint = tester.getRect(find.byType(Glint));
      // On the empty state Glint is a small badge on the cover mosaic; it must never stretch to the list width.
      expect(glint.width, lessThanOrEqualTo(120), reason: 'Glint stretched to the list width paints over the copy');
      expect(glint.width, glint.height);
      expect(glint.bottom, lessThan(tester.getRect(title).top));
      expect(title.hitTestable(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.scrollUntilVisible(upload, 150, scrollable: find.byType(Scrollable).first);
      expect(upload.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('tips summary shows totals, the last week and the wall', (tester) async {
    final raw = fixture();
    raw['tips'] = tipsFixture(raw);
    await pump(tester, CreatorStatsState(data: parseCreatorStats(raw)));
    await tester.scrollUntilVisible(find.text('Tips'), 300);
    expect(find.text('Tips'), findsOneWidget);
    expect(find.text('2 tips, 35 coins in all'), findsOneWidget);
    expect(find.text('Week of Oct 19: 2 tips, 35 coins'), findsOneWidget);
    expect(find.text('Blue sky: 1 tip, 25 coins'), findsOneWidget);
  });
  testWidgets('tips summary shows the empty copy without tips', (tester) async {
    await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())));
    await tester.scrollUntilVisible(find.text('Tips'), 300);
    expect(find.text('No tips yet. Fans can tip you from your walls and your profile.'), findsOneWidget);
  });
  testWidgets('metric switch dispatches and tracks typed event', (tester) async {
    final bloc = await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())));
    await tester.scrollUntilVisible(find.text('Saves'), 300);
    await tester.ensureVisible(find.text('Saves'));
    await tester.pump();
    await tester.tap(find.text('Saves'));
    verify(() => bloc.add(const CreatorStatsEvent.select(StatsMetric.saves))).called(1);
    expect(analytics.events.map((event) => event.eventName), contains('creator_stats_metric_switched'));
    expect(analytics.events.where((event) => event.eventName == 'creator_stats_metric_switched'), hasLength(1));
  });
  testWidgets('loaded dashboard and chart adapt to large text', (tester) async {
    await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())), scale: 2);
    await tester.scrollUntilVisible(find.byType(StatsChart), 300);
    await tester.ensureVisible(find.byType(StatsChart));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('chart bars are readable buttons at narrow width and large text', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The readout Text repeats the selected bar's label, so count only the bar buttons.
    Finder bar(String label) =>
        find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && w.properties.label == label);
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
      expect(bar(label), findsOneWidget);
    }
    expect(find.text('Week of Oct 19, 2026: 7'), findsOneWidget);
    await tester.tap(bar('Week of Sep 14, 2026: 2'));
    await tester.pump();
    expect(find.text('Week of Sep 14, 2026: 2'), findsOneWidget);
    expect(find.text('Week of Oct 19, 2026: 7'), findsNothing);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
  testWidgets('chart clears a picked week when its metric changes', (tester) async {
    final data = parseCreatorStats(fixture());
    Widget chart(StatsMetric metric) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StatsChart(weeks: data.weeks, metric: metric),
      ),
    );
    await tester.pumpWidget(chart(StatsMetric.views));
    final selectedBar = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.button == true && w.properties.label == 'Week of Sep 14, 2026: 2',
    );
    await tester.tap(selectedBar);
    await tester.pump();
    expect(find.text('Week of Sep 14, 2026: 2'), findsOneWidget);
    await tester.pumpWidget(chart(StatsMetric.saves));
    await tester.pump();
    expect(find.text('Week of Oct 19, 2026: 7'), findsOneWidget);
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
    expect(analytics.events.where((event) => event.eventName == 'creator_wall_stats_opened'), hasLength(1));
    expect(find.bySemanticsLabel('Week of Aug 31, 2026: Unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Week of Oct 19, 2026: 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
  testWidgets('hero shows this week with the change and the total', (tester) async {
    await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())));
    expect(find.text('VIEWS'), findsOneWidget);
    expect(find.text('+1 (+17%) vs last week'), findsOneWidget);
    expect(find.text('Total: 10'), findsOneWidget);
    expect(find.text('7'), findsWidgets);
  });
  testWidgets('period switch changes the hero and the comparison', (tester) async {
    final bloc = await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())));
    await tester.tap(find.text('Last week'));
    await tester.pump();
    expect(find.text('+1 (+20%) vs the week before'), findsOneWidget);
    await tester.tap(find.text('4 weeks'));
    await tester.pump();
    expect(find.text('Not enough history to compare'), findsOneWidget);
    expect(find.text('22'), findsWidgets);
    verifyNever(() => bloc.add(any()));
    expect(analytics.events.map((event) => event.eventName), isNot(contains('creator_stats_metric_switched')));
  });
  testWidgets('walls with no views show the calm chart state', (tester) async {
    final raw = fixture();
    List<Object?> zeroWeeks(List<Object?> weeks) => [
      for (var i = 0; i < weeks.length; i++)
        {
          ...weeks[i]! as Map<String, Object?>,
          'metrics': {for (final m in StatsMetric.values) m.name: 0},
        },
    ];
    raw['weeks'] = zeroWeeks(raw['weeks']! as List<Object?>);
    final wall = (raw['walls']! as List).single as Map<String, Object?>;
    raw['walls'] = [
      {...wall, 'weeks': zeroWeeks(wall['weeks']! as List<Object?>)},
    ];
    await pump(tester, CreatorStatsState(data: parseCreatorStats(raw)));
    expect(find.text('Nothing recorded in these eight weeks yet.'), findsOneWidget);
    expect(find.text('No change vs last week'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Blue sky'), 300);
    expect(find.text('Blue sky'), findsOneWidget);
  });
  testWidgets('mixed zero and unavailable weeks retain the chart and all bar actions', (tester) async {
    final raw = fixture();
    final weeks = raw['weeks']! as List;
    for (var i = 0; i < weeks.length; i++) {
      (weeks[i] as Map<String, Object?>)['metrics'] = {
        for (final metric in StatsMetric.values) metric.name: i.isEven ? 0 : null,
      };
    }
    final data = parseCreatorStats(raw);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatsChart(weeks: data.weeks, metric: StatsMetric.views),
        ),
      ),
    );
    expect(find.text('Nothing recorded in these eight weeks yet.'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true), findsNWidgets(8));
    expect(find.bySemanticsLabel('Week of Aug 31, 2026: 0'), findsOneWidget);
    expect(find.bySemanticsLabel('Week of Sep 7, 2026: Unavailable'), findsOneWidget);
  });
  testWidgets('chart date labels keep a gap and retain the newest label at 390px', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = parseCreatorStats(fixture());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StatsChart(weeks: data.weeks, metric: StatsMetric.views),
          ),
        ),
      ),
    );
    final render = tester.renderObject<RenderCustomPaint>(
      find.descendant(of: find.byType(StatsChart), matching: find.byType(CustomPaint)),
    );
    final canvas = _ParagraphBoundsCanvas();
    render.painter!.paint(canvas, render.size);
    final bottom = canvas.bounds.map((entry) => entry.$2.dy).reduce((a, b) => a > b ? a : b);
    final paragraphs = canvas.bounds.where((entry) => entry.$2.dy >= bottom - 1).toList()
      ..sort((a, b) => a.$2.dx.compareTo(b.$2.dx));
    expect(paragraphs, isNotEmpty);
    for (var i = 1; i < paragraphs.length; i++) {
      expect(paragraphs[i - 1].$2.dx + paragraphs[i - 1].$1 + 4, lessThanOrEqualTo(paragraphs[i].$2.dx));
    }
    expect(paragraphs.last.$2.dx + paragraphs.last.$1, greaterThan(render.size.width * 0.75));
  });
  testWidgets('top walls list caps at five with show all', (tester) async {
    final raw = fixture();
    final original = (raw['walls']! as List).single as Map<String, Object?>;
    raw['approvedWallCount'] = 7;
    raw['walls'] = [
      for (var i = 0; i < 7; i++) {...original, 'wallId': 'w$i', 'title': 'Wall $i'},
    ];
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, CreatorStatsState(data: parseCreatorStats(raw)));
    await tester.scrollUntilVisible(find.text('Show all 7 walls'), 300);
    expect(find.textContaining('Wall '), findsNWidgets(5));
    await tester.tap(find.text('Show all 7 walls'));
    await tester.pump();
    expect(find.textContaining('Wall '), findsNWidgets(7));
    expect(find.text('Show fewer'), findsOneWidget);
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('long top-wall title and 16-digit value fit at 200% on ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final raw = fixture();
      final wall = (raw['walls']! as List).single as Map<String, Object?>;
      wall['title'] = 'A very long wallpaper title that needs room to wrap safely';
      const safeInteger = 9007199254740991;
      wall['totals'] = {for (final m in StatsMetric.values) m.name: safeInteger};
      final wallWeeks = (wall['weeks']! as List).toList();
      final finalWeek = wallWeeks.last as Map<String, Object?>;
      wallWeeks[wallWeeks.length - 1] = {
        ...finalWeek,
        'metrics': {for (final m in StatsMetric.values) m.name: safeInteger},
      };
      wall['weeks'] = wallWeeks;
      raw['tips'] = tipsFixture(raw);
      await pump(tester, CreatorStatsState(data: parseCreatorStats(raw)), scale: 2);
      await tester.scrollUntilVisible(find.text('Tips'), 250);
      expect(find.text('Tips'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(wall['title']! as String), -250);
      expect(find.text(wall['title']! as String), findsOneWidget);
      expect(find.text('9,007,199,254,740,991'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(wall['title']! as String));
      await tester.pumpAndSettle();
      expect(find.byType(WallStatsPage), findsOneWidget);
      expect(MediaQuery.textScalerOf(tester.element(find.byType(WallStatsPage))).scale(10), 20);
      await tester.scrollUntilVisible(find.text('About these numbers'), 250);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('whole dashboard fits 320 wide at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, CreatorStatsState(data: parseCreatorStats(fixture())), scale: 2);
    await tester.scrollUntilVisible(find.text('About these numbers'), 300, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
