import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/creator_fund/biz/bloc/creator_fund_bloc.j.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_repository.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:Prism/features/creator_stats/biz/bloc/creator_stats_bloc.j.dart';
import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:Prism/features/creator_stats/views/pages/creator_stats_page.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockStatsBloc extends MockBloc<CreatorStatsEvent, CreatorStatsState> implements CreatorStatsBloc {}

class _OffFund implements CreatorFundRepository {
  @override
  Future<CreatorFundStatus> load() async => const CreatorFundOff(week: '2026-W46');
}

const Map<String, List<String>> _fonts = <String, List<String>>{
  'Proxima Nova': <String>['assets/fonts/ProximaNova-Regular.otf', 'assets/fonts/Proxima Nova Bold.otf'],
  'Fraunces': <String>['assets/fonts/Fraunces-Variable.ttf'],
  'MaterialIcons': <String>['fonts/MaterialIcons-Regular.otf'],
};

/// Goldens are drawn on Linux, the CI host. Font rendering differs on macOS, so they are skipped there.
final bool _linuxOnly = !Platform.isLinux;

CreatorStats _stats({bool zero = false}) {
  final start = DateTime.utc(2026, 9, 28);
  List<StatsWeek> history(List<int?> views) => [
    for (var i = 0; i < 8; i++)
      StatsWeek(
        week: '2026-W${40 + i}',
        start: start.add(Duration(days: 7 * i)),
        endExclusive: start.add(Duration(days: 7 * (i + 1))),
        metrics: {
          for (final metric in StatsMetric.values)
            metric: views[i] == null ? null : (zero ? 0 : views[i]! ~/ (metric.index * 3 + 1)),
        },
      ),
  ];
  final weeks = history([null, 412, 630, 588, 902, 1104, 1072, 1284]);
  final walls = [
    for (final (id, title, share) in [('a', 'Blue hour', 2), ('b', 'Glass dunes', 3), ('c', 'Night tram', 5)])
      WallStats(
        wallId: id,
        title: title,
        thumbnailUrl: '',
        totals: {for (final metric in StatsMetric.values) metric: zero ? 0 : 4210 ~/ share},
        weeks: [
          for (final week in weeks)
            StatsWeek(
              week: week.week,
              start: week.start,
              endExclusive: week.endExclusive,
              metrics: {for (final e in week.metrics.entries) e.key: e.value == null ? null : e.value! ~/ share},
            ),
        ],
      ),
  ];
  return CreatorStats(
    generatedAt: DateTime.utc(2026, 11, 19, 9),
    asOf: DateTime.utc(2026, 11, 19, 9),
    approvedWallCount: walls.length,
    totals: {for (final metric in StatsMetric.values) metric: zero ? 0 : 9640 ~/ (metric.index * 3 + 1)},
    coverage: const {},
    weeks: weeks,
    walls: walls,
    tips: zero
        ? CreatorTips.empty
        : CreatorTips(
            count: 3,
            coins: 45,
            weeks: [
              for (final week in weeks)
                TipWeek(
                  week: week.week,
                  start: week.start,
                  count: week == weeks.last ? 2 : 0,
                  coins: week == weeks.last ? 35 : 0,
                ),
            ],
            walls: const {'a': TipTally(count: 2, coins: 35), 'c': TipTally(count: 1, coins: 10)},
          ),
  );
}

void main() {
  setUpAll(() async {
    for (final font in _fonts.entries) {
      final loader = FontLoader(font.key);
      for (final asset in font.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  Future<void> render(
    WidgetTester tester,
    String name, {
    required ThemeData theme,
    required Size size,
    CreatorStats? data,
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bloc = _MockStatsBloc();
    when(() => bloc.state).thenReturn(CreatorStatsState(data: data ?? _stats()));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CreatorStatsBloc>.value(value: bloc),
          BlocProvider<CreatorFundBloc>(create: (_) => CreatorFundBloc(_OffFund())..add(const CreatorFundEvent.load())),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!,
          ),
          home: const CreatorStatsView(ownerUid: 'alice'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(CreatorStatsView), matchesGoldenFile('goldens/creator_stats_$name.png'));
  }

  final amoled = prismThemeById(prismDarkThemes, prismAmoledDarkThemeId)!.theme;
  testWidgets(
    'light',
    (t) => render(t, 'light', theme: prismLightThemes.first.theme, size: const Size(390, 1900)),
    skip: _linuxOnly,
  );
  testWidgets(
    'dark',
    (t) => render(t, 'dark', theme: prismDarkThemes.first.theme, size: const Size(390, 1900)),
    skip: _linuxOnly,
  );
  testWidgets(
    'amoled with a user accent',
    (t) => render(t, 'amoled_accent', theme: withPrismAccent(amoled, 0xFF4FC3F7), size: const Size(390, 1900)),
    skip: _linuxOnly,
  );
  testWidgets(
    'large text at 320 wide',
    (t) => render(t, 'large_text', theme: prismLightThemes.first.theme, size: const Size(320, 3600), scale: 2),
    skip: _linuxOnly,
  );
  testWidgets(
    'tablet',
    (t) => render(t, 'tablet', theme: prismLightThemes.first.theme, size: const Size(1024, 1500)),
    skip: _linuxOnly,
  );
  testWidgets(
    'walls with no views',
    (t) =>
        render(t, 'zero', theme: prismLightThemes.first.theme, size: const Size(390, 1500), data: _stats(zero: true)),
    skip: _linuxOnly,
  );
}
