import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
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

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

DayNightWall _wall(String id) =>
    DayNightWall(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: '');

final DayNightPair _completePair = DayNightPair(day: _wall('day'), night: _wall('night'));
final DayNightPair _enabledPair = DayNightPair(day: _wall('day'), night: _wall('night'), enabled: true);

void main() {
  late _MockDayNightBloc bloc;
  late _MockAutoRotateBloc autoRotateBloc;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    bloc = _MockDayNightBloc();
    autoRotateBloc = _MockAutoRotateBloc();
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
  });

  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpScreen(
    WidgetTester tester,
    DayNightState state, {
    ThemeData? theme,
    double textScale = 1,
    bool disableAnimations = false,
    bool alwaysUse24HourFormat = false,
    AutoRotateState? autoRotate,
  }) {
    whenListen(bloc, const Stream<DayNightState>.empty(), initialState: state);
    whenListen(
      autoRotateBloc,
      const Stream<AutoRotateState>.empty(),
      initialState: autoRotate ?? AutoRotateState.initial(),
    );
    return _pump(
      tester,
      bloc,
      autoRotateBloc,
      theme: theme,
      textScale: textScale,
      disableAnimations: disableAnimations,
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    );
  }

  final AutoRotateState autoRotateOn = AutoRotateState.initial().copyWith(
    config: const AutoRotateConfig(enabled: true),
  );

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
    await _pump(tester, bloc, autoRotateBloc, disableAnimations: true);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    states.add(DayNightState(pair: _completePair, isPro: true, loaded: true));
    await tester.pump();

    expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
  });

  testWidgets('Android shows the Android intro, Around times, and the timing note without Shortcuts', (tester) async {
    await pumpScreen(
      tester,
      DayNightState(pair: _completePair, isPro: true, loaded: true),
      alwaysUse24HourFormat: true,
    );

    expect(
      find.text('Pick a wall for the day and one for the night. Prism switches them at the times you set.'),
      findsOneWidget,
    );
    expect(find.text('Around 07:00'), findsOneWidget);
    expect(find.text('Around 19:00'), findsOneWidget);
    expect(find.text('Android can switch a few minutes late to save battery.'), findsOneWidget);
    expect(find.text('Set up in Shortcuts'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS shows Set up in Shortcuts and plain row times', (tester) async {
    await pumpScreen(tester, DayNightState(pair: _enabledPair, isPro: true, loaded: true), alwaysUse24HourFormat: true);

    expect(find.text('Set up in Shortcuts'), findsOneWidget);
    expect(find.descendant(of: find.byType(PrismRow).first, matching: find.text('07:00')), findsOneWidget);
    expect(find.text('Around 07:00'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android with auto-rotate on asks first, then turns auto-rotate off and Day and night on', (
    tester,
  ) async {
    final StreamController<AutoRotateState> states = StreamController<AutoRotateState>();
    addTearDown(states.close);
    whenListen(
      bloc,
      const Stream<DayNightState>.empty(),
      initialState: DayNightState(pair: _completePair, isPro: true, loaded: true),
    );
    whenListen(autoRotateBloc, states.stream, initialState: autoRotateOn);
    await _pump(tester, bloc, autoRotateBloc);

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Turn off auto-rotate?'), findsOneWidget);
    verifyNever(() => bloc.add(const DayNightEvent.toggled(true)));

    await tester.tap(find.text('Turn off auto-rotate'));
    await tester.pumpAndSettle();

    verify(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false))).called(1);
    verifyNever(() => bloc.add(const DayNightEvent.toggled(true)));

    states.add(AutoRotateState.initial());
    await tester.pumpAndSettle();

    verify(() => bloc.add(const DayNightEvent.toggled(true))).called(1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android with auto-rotate on, cancelling the sheet changes nothing', (tester) async {
    await pumpScreen(tester, DayNightState(pair: _completePair, isPro: true, loaded: true), autoRotate: autoRotateOn);

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Turn off auto-rotate?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false)));
    verifyNever(() => bloc.add(const DayNightEvent.toggled(true)));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android large text lays out a complete pair in light and dark with Around times', (tester) async {
    final DayNightState state = DayNightState(pair: _enabledPair, isPro: true, loaded: true);

    await pumpScreen(tester, state, theme: ThemeData.light(), textScale: 2, alwaysUse24HourFormat: true);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Around 07:00'));
    expect(find.text('Around 07:00'), findsOneWidget);

    expect(
      tester.getSize(find.text('Day starts')).width,
      greaterThan(tester.getSize(find.text('Around 07:00')).width / 2),
    );

    await pumpScreen(tester, state, theme: ThemeData.dark(), textScale: 2, alwaysUse24HourFormat: true);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Around 07:00'));
    expect(find.text('Around 07:00'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

Future<void> _pump(
  WidgetTester tester,
  DayNightBloc bloc,
  AutoRotateBloc autoRotateBloc, {
  ThemeData? theme,
  double textScale = 1,
  bool disableAnimations = false,
  bool alwaysUse24HourFormat = false,
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          alwaysUse24HourFormat: alwaysUse24HourFormat,
        ),
        child: child!,
      ),
      home: BlocProvider<AutoRotateBloc>.value(
        value: autoRotateBloc,
        child: BlocProvider<DayNightBloc>.value(value: bloc, child: const DayNightScreen()),
      ),
    ),
  );
}
