import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_mode.dart';
import 'package:Prism/features/auto_rotate/views/widgets/auto_rotate_mode_confirm.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAutoRotateBloc extends MockBloc<AutoRotateEvent, AutoRotateState> implements AutoRotateBloc {}

class _MockDayNightBloc extends MockBloc<DayNightEvent, DayNightState> implements DayNightBloc {}

DayNightWall _wall(String id) =>
    DayNightWall(id: id, source: WallpaperSource.prism, fullUrl: 'https://example.com/$id.jpg', thumbnailUrl: '');

final DayNightPair _enabledPair = DayNightPair(day: _wall('day'), night: _wall('night'), enabled: true);

void main() {
  late _MockAutoRotateBloc autoRotateBloc;
  late _MockDayNightBloc dayNightBloc;

  setUp(() {
    autoRotateBloc = _MockAutoRotateBloc();
    dayNightBloc = _MockDayNightBloc();
    whenListen(autoRotateBloc, const Stream<AutoRotateState>.empty(), initialState: AutoRotateState.initial());
    whenListen(dayNightBloc, const Stream<DayNightState>.empty(), initialState: DayNightState.initial());
  });

  Future<void> pumpHarness(WidgetTester tester, {required AutoRotateMode mode, required List<bool> results}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AutoRotateBloc>.value(
          value: autoRotateBloc,
          child: BlocProvider<DayNightBloc>.value(
            value: dayNightBloc,
            child: _Harness(mode: mode, onResult: results.add),
          ),
        ),
      ),
    );
  }

  Future<void> tapGo(WidgetTester tester) async {
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
  }

  testWidgets('playlist mode with Day and night off returns true with no sheet and no events', (tester) async {
    final List<bool> results = <bool>[];
    whenListen(dayNightBloc, const Stream<DayNightState>.empty(), initialState: DayNightState(pair: DayNightPair()));
    await pumpHarness(tester, mode: AutoRotateMode.playlist, results: results);

    await tapGo(tester);

    expect(results, <bool>[true]);
    expect(find.text('Turn off Day and night?'), findsNothing);
    verifyNever(() => dayNightBloc.add(const DayNightEvent.toggled(false)));
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false)));
  });

  testWidgets('playlist mode with Day and night on asks, and confirm turns it off and returns true', (tester) async {
    final List<bool> results = <bool>[];
    final StreamController<DayNightState> states = StreamController<DayNightState>();
    addTearDown(states.close);
    whenListen(dayNightBloc, states.stream, initialState: DayNightState(pair: _enabledPair));
    when(() => dayNightBloc.add(const DayNightEvent.toggled(false))).thenAnswer((_) {
      states.add(DayNightState(pair: _enabledPair.copyWith(enabled: false)));
    });
    await pumpHarness(tester, mode: AutoRotateMode.playlist, results: results);

    await tapGo(tester);

    expect(find.text('Turn off Day and night?'), findsOneWidget);
    expect(
      find.text('Auto-rotate and Day and night both change your wallpaper. Only one can be on at a time.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Turn off Day and night'));
    await tester.pumpAndSettle();

    expect(results, <bool>[true]);
    verify(() => dayNightBloc.add(const DayNightEvent.toggled(false))).called(1);
  });

  testWidgets('playlist mode waits for Day and night to stop before allowing the new mode', (tester) async {
    final List<bool> results = <bool>[];
    final StreamController<DayNightState> states = StreamController<DayNightState>();
    addTearDown(states.close);
    whenListen(dayNightBloc, states.stream, initialState: DayNightState(pair: _enabledPair));
    when(() => dayNightBloc.add(const DayNightEvent.toggled(false))).thenAnswer((_) {});
    await pumpHarness(tester, mode: AutoRotateMode.playlist, results: results);

    await tapGo(tester);
    await tester.tap(find.text('Turn off Day and night'));
    await tester.pump();

    verify(() => dayNightBloc.add(const DayNightEvent.toggled(false))).called(1);
    expect(results, isEmpty);

    states.add(DayNightState(pair: _enabledPair.copyWith(enabled: false)));
    await tester.pumpAndSettle();

    expect(results, <bool>[true]);
  });

  testWidgets('playlist mode with Day and night on, cancel returns false and adds no event', (tester) async {
    final List<bool> results = <bool>[];
    whenListen(dayNightBloc, const Stream<DayNightState>.empty(), initialState: DayNightState(pair: _enabledPair));
    await pumpHarness(tester, mode: AutoRotateMode.playlist, results: results);

    await tapGo(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, <bool>[false]);
    verifyNever(() => dayNightBloc.add(const DayNightEvent.toggled(false)));
  });

  testWidgets('confirm accepts a playlist that stopped while the sheet was open', (tester) async {
    final List<bool> results = <bool>[];
    final StreamController<AutoRotateState> states = StreamController<AutoRotateState>();
    addTearDown(states.close);
    whenListen(
      autoRotateBloc,
      states.stream,
      initialState: AutoRotateState.initial().copyWith(config: const AutoRotateConfig(enabled: true)),
    );
    await pumpHarness(tester, mode: AutoRotateMode.dayNight, results: results);
    await tapGo(tester);
    states.add(AutoRotateState.initial());
    await tester.pump();

    await tester.tap(find.text('Turn off auto-rotate'));
    await tester.pumpAndSettle();

    expect(results, <bool>[true]);
    verifyNever(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false)));
  });

  testWidgets('failed playlist stop refuses the new mode instead of waiting forever', (tester) async {
    final List<bool> results = <bool>[];
    final StreamController<AutoRotateState> states = StreamController<AutoRotateState>();
    addTearDown(states.close);
    whenListen(
      autoRotateBloc,
      states.stream,
      initialState: AutoRotateState.initial().copyWith(config: const AutoRotateConfig(enabled: true)),
    );
    when(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false))).thenAnswer((_) {
      states.add(
        AutoRotateState.initial().copyWith(status: const AutoRotateStatus(isRunning: true, lastError: 'Stop failed')),
      );
    });
    await pumpHarness(tester, mode: AutoRotateMode.dayNight, results: results);
    await tapGo(tester);

    await tester.tap(find.text('Turn off auto-rotate'));
    await tester.pumpAndSettle();

    expect(results, <bool>[false]);
  });

  testWidgets('failed Day and night stop refuses the new mode', (tester) async {
    final List<bool> results = <bool>[];
    final StreamController<DayNightState> states = StreamController<DayNightState>();
    addTearDown(states.close);
    whenListen(dayNightBloc, states.stream, initialState: DayNightState(pair: _enabledPair));
    when(() => dayNightBloc.add(const DayNightEvent.toggled(false))).thenAnswer((_) {
      states.add(DayNightState(pair: _enabledPair, issue: DayNightIssue.offlineCopyFailed));
    });
    await pumpHarness(tester, mode: AutoRotateMode.playlist, results: results);
    await tapGo(tester);

    await tester.tap(find.text('Turn off Day and night'));
    await tester.pumpAndSettle();

    expect(results, <bool>[false]);
  });

  testWidgets('dayNight mode asks when auto-rotate is running even if config is off', (tester) async {
    final List<bool> results = <bool>[];
    final StreamController<AutoRotateState> states = StreamController<AutoRotateState>();
    addTearDown(states.close);
    whenListen(
      autoRotateBloc,
      states.stream,
      initialState: AutoRotateState.initial().copyWith(status: const AutoRotateStatus(isRunning: true)),
    );
    when(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false))).thenAnswer((_) {
      states.add(AutoRotateState.initial());
    });
    await pumpHarness(tester, mode: AutoRotateMode.dayNight, results: results);

    await tapGo(tester);

    expect(find.text('Turn off auto-rotate?'), findsOneWidget);

    await tester.tap(find.text('Turn off auto-rotate'));
    await tester.pumpAndSettle();

    expect(results, <bool>[true]);
    verify(() => autoRotateBloc.add(const AutoRotateEvent.toggled(false))).called(1);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.mode, required this.onResult});

  final AutoRotateMode mode;
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final bool result = await confirmAutoRotateMode(context, mode);
            onResult(result);
          },
          child: const Text('Go'),
        ),
      ),
    );
  }
}
