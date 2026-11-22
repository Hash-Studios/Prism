import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_fund/biz/bloc/creator_fund_bloc.j.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_repository.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:Prism/features/creator_stats/biz/bloc/creator_stats_bloc.j.dart';
import 'package:Prism/features/creator_stats/data/creator_stats_repository_impl.dart';
import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/creator_stats/views/pages/creator_stats_page.dart';
import 'package:Prism/features/creator_walls/creator_walls.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatsBloc extends MockBloc<CreatorStatsEvent, CreatorStatsState> implements CreatorStatsBloc {}

class _MockSessionBloc extends MockBloc<SessionEvent, SessionState> implements SessionBloc {}

class _OffFund implements CreatorFundRepository {
  @override
  Future<CreatorFundStatus> load() async => const CreatorFundOff(week: '2026-W46');
}

Map<String, Object?> _stats() {
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
    'approvedWallCount': 1,
    'totals': totals,
    'coverage': {
      for (final m in StatsMetric.values)
        m.name: {'weeklyFrom': null, 'totalBasis': 'currentMembership', 'totalFrom': null},
    },
    'weeks': weeks,
    'walls': [
      {'wallId': 'one', 'title': 'Blue sky', 'thumbnailUrl': '', 'totals': totals, 'weeks': weeks},
    ],
  };
}

/// Sales for [stats]: 3 unlocks and 70 coins in the last week, all on wall 'one'.
Map<String, Object?> _salesFixture(Map<String, Object?> stats) {
  final weeks = (stats['weeks']! as List).cast<Map<String, Object?>>();
  final last = weeks.length - 1;
  return {
    'count': 3,
    'coins': 70,
    'weeks': [
      for (var i = 0; i < weeks.length; i++)
        {'week': weeks[i]['week'], 'start': weeks[i]['start'], 'count': i == last ? 3 : 0, 'coins': i == last ? 70 : 0},
    ],
    'walls': [
      {'wallId': 'one', 'count': 3, 'coins': 70},
    ],
  };
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
  tearDown(() => CreatorWallsFlag.debugEnabled = null);

  test('payload with sales parses the same as tips', () {
    final raw = _stats();
    raw['sales'] = _salesFixture(raw);
    final stats = parseCreatorStats(raw);
    expect(stats.sales.count, 3);
    expect(stats.sales.coins, 70);
    expect(stats.sales.weeks, hasLength(8));
    expect(stats.sales.weeks.last.count, 3);
    expect(stats.sales.walls['one']!.coins, 70);
  });

  test('payload without sales parses as no sales', () {
    final stats = parseCreatorStats(_stats());
    expect(stats.sales.count, 0);
    expect(stats.sales.coins, 0);
    expect(stats.sales.weeks, isEmpty);
    expect(stats.sales.walls, isEmpty);
  });

  Future<_MockStatsBloc> pump(WidgetTester tester, CreatorStatsState state, {double scale = 1}) async {
    final bloc = _MockStatsBloc();
    when(() => bloc.state).thenReturn(state);
    final session = _MockSessionBloc();
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

  testWidgets('sales section shows counts and a wall row when there are sales', (tester) async {
    CreatorWallsFlag.debugEnabled = false;
    final raw = _stats();
    raw['sales'] = _salesFixture(raw);
    await pump(tester, CreatorStatsState(data: parseCreatorStats(raw)));
    await tester.scrollUntilVisible(find.text('Sales'), 300);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Unlocks'), findsOneWidget);
    expect(find.text('Coins earned'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('70'), findsOneWidget);
    final salesRow = find.ancestor(of: find.text('3 unlocks, 70 coins'), matching: find.byType(PrismRow));
    expect(salesRow, findsOneWidget);
    expect(find.descendant(of: salesRow, matching: find.text('Blue sky')), findsOneWidget);
    expect(find.text('No sales yet. Put a price on one of your walls to sell it.'), findsNothing);
  });

  testWidgets('sales section is hidden when the flag is off and there are no sales', (tester) async {
    CreatorWallsFlag.debugEnabled = false;
    await pump(tester, CreatorStatsState(data: parseCreatorStats(_stats())));
    await tester.scrollUntilVisible(find.text('About these numbers'), 300);
    expect(find.text('Sales'), findsNothing);
    expect(find.text('No sales yet. Put a price on one of your walls to sell it.'), findsNothing);
  });

  testWidgets('sales section shows the empty line when the flag is on with no sales', (tester) async {
    CreatorWallsFlag.debugEnabled = true;
    await pump(tester, CreatorStatsState(data: parseCreatorStats(_stats())));
    await tester.scrollUntilVisible(find.text('Sales'), 300);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('No sales yet. Put a price on one of your walls to sell it.'), findsOneWidget);
    expect(find.text('Unlocks'), findsNothing);
  });

  testWidgets('sales section fits 320 wide at 200% text with sales', (tester) async {
    CreatorWallsFlag.debugEnabled = true;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final raw = _stats();
    raw['sales'] = _salesFixture(raw);
    await pump(tester, CreatorStatsState(data: parseCreatorStats(raw)), scale: 2);
    await tester.scrollUntilVisible(find.text('Sales'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Sales'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('About these numbers'), 300, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
