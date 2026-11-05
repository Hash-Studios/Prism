import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/views/pages/day_night_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockDayNightBloc extends MockBloc<DayNightEvent, DayNightState> implements DayNightBloc {}

DayNightWall _wall(String id) =>
    DayNightWall(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: '');

final DayNightPair _completePair = DayNightPair(day: _wall('day'), night: _wall('night'));
final DayNightPair _enabledPair = DayNightPair(day: _wall('day'), night: _wall('night'), enabled: true);

void main() {
  late _MockDayNightBloc bloc;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    bloc = _MockDayNightBloc();
  });

  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpScreen(
    WidgetTester tester,
    DayNightState state, {
    ThemeData? theme,
    double textScale = 1,
    bool disableAnimations = false,
  }) {
    whenListen(bloc, const Stream<DayNightState>.empty(), initialState: state);
    return _pump(tester, bloc, theme: theme, textScale: textScale, disableAnimations: disableAnimations);
  }

  testWidgets('an empty pair shows both empty slots and a disabled switch for Pro', (tester) async {
    await pumpScreen(tester, DayNightState(pair: DayNightPair(), isPro: true, loaded: true));

    expect(find.text('Hold any wallpaper, then tap Use as day wall.'), findsOneWidget);
    expect(find.text('Hold any wallpaper, then tap Use as night wall.'), findsOneWidget);
    expect(find.text('Day starts'), findsOneWidget);
    expect(find.text('7:00 AM'), findsWidgets);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('Pick a day wall and a night wall first.'), findsOneWidget);
  });

  testWidgets('a complete pair shows its captions and enabling the switch toggles it on', (tester) async {
    await pumpScreen(tester, DayNightState(pair: _completePair, isPro: true, loaded: true));

    expect(find.text('From 7:00 AM'), findsOneWidget);
    expect(find.text('From 7:00 PM'), findsOneWidget);

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));

    verify(() => bloc.add(const DayNightEvent.toggled(true))).called(1);
  });

  testWidgets('a free user sees the Pro card and no switch', (tester) async {
    await pumpScreen(tester, DayNightState(pair: _completePair, loaded: true));

    expect(find.text('Day and night is a Prism Pro feature.'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('equal times show the error', (tester) async {
    await pumpScreen(
      tester,
      DayNightState(pair: _completePair, isPro: true, loaded: true, issue: DayNightIssue.timesEqual),
    );

    expect(find.text('Pick two different times.'), findsOneWidget);
  });

  testWidgets('a failed offline copy shows the error and Try again retries', (tester) async {
    await pumpScreen(
      tester,
      DayNightState(pair: _completePair, isPro: true, loaded: true, issue: DayNightIssue.offlineCopyFailed),
    );

    expect(find.text('Could not save the walls for offline use. Check your connection.'), findsOneWidget);

    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));

    verify(() => bloc.add(const DayNightEvent.retryPressed())).called(1);
  });

  testWidgets('tapping a target segment dispatches targetChanged', (tester) async {
    await pumpScreen(tester, DayNightState(pair: _completePair, isPro: true, loaded: true));

    await tester.tap(find.text('Lock screen'));

    verify(() => bloc.add(const DayNightEvent.targetChanged(WallpaperTarget.lock))).called(1);
  });

  testWidgets('large text lays out a complete enabled pair without overflow in light and dark', (tester) async {
    final DayNightState state = DayNightState(pair: _enabledPair, isPro: true, loaded: true);

    await pumpScreen(tester, state, theme: ThemeData.light(), textScale: 2);
    expect(tester.takeException(), isNull);

    await pumpScreen(tester, state, theme: ThemeData.dark(), textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduce motion a wall change shows the new state after one pump', (tester) async {
    final StreamController<DayNightState> states = StreamController<DayNightState>();
    addTearDown(states.close);
    whenListen(bloc, states.stream, initialState: DayNightState(pair: DayNightPair(), isPro: true, loaded: true));
    await _pump(tester, bloc, disableAnimations: true);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    states.add(DayNightState(pair: _completePair, isPro: true, loaded: true));
    await tester.pump();

    expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  DayNightBloc bloc, {
  ThemeData? theme,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: disableAnimations),
        child: child!,
      ),
      home: BlocProvider<DayNightBloc>.value(value: bloc, child: const DayNightScreen()),
    ),
  );
}
