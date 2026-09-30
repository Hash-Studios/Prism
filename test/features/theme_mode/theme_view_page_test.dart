import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/theme_dark/theme_dark.dart';
import 'package:Prism/features/theme_light/domain/entities/theme_light.dart';
import 'package:Prism/features/theme_light/theme_light.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_mode.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockThemeLightBloc extends MockBloc<ThemeLightEvent, ThemeLightState> implements ThemeLightBloc {}

class _MockThemeDarkBloc extends MockBloc<ThemeDarkEvent, ThemeDarkState> implements ThemeDarkBloc {}

class _MockThemeModeBloc extends MockBloc<ThemeModeEvent, ThemeModeState> implements ThemeModeBloc {}

void main() {
  late _MockThemeLightBloc lightBloc;
  late _MockThemeDarkBloc darkBloc;
  late _MockThemeModeBloc modeBloc;

  setUpAll(() {
    if (!getIt.isRegistered<SettingsLocalDataSource>()) {
      getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    }
  });

  setUp(() {
    lightBloc = _MockThemeLightBloc();
    darkBloc = _MockThemeDarkBloc();
    modeBloc = _MockThemeModeBloc();
    when(() => lightBloc.state).thenReturn(ThemeLightState.initial());
    when(() => darkBloc.state).thenReturn(ThemeDarkState.initial());
  });

  Future<void> pumpPage(WidgetTester tester, ThemeMode mode) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => modeBloc.state).thenReturn(ThemeModeState.initial().copyWith(mode: ThemeModeEntity(mode: mode)));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ThemeLightBloc>.value(value: lightBloc),
          BlocProvider<ThemeDarkBloc>.value(value: darkBloc),
          BlocProvider<ThemeModeBloc>.value(value: modeBloc),
        ],
        child: MaterialApp(theme: ThemeData.light(), home: const ThemeView()),
      ),
    );
  }

  testWidgets('system mode shows the light and the dark pickers', (tester) async {
    await pumpPage(tester, ThemeMode.system);

    expect(find.text('Light Themes'), findsOneWidget);
    expect(find.text('Dark Themes'), findsOneWidget);
    expect(find.text('Light Accent Color'), findsOneWidget);
    expect(find.text('Dark Accent Color'), findsOneWidget);
    expect(find.text('System (Light/Dark)'), findsOneWidget);
  });

  testWidgets('light mode hides the dark pickers', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    expect(find.text('Light Themes'), findsOneWidget);
    expect(find.text('Dark Themes'), findsNothing);
    expect(find.text('Dark Accent Color'), findsNothing);
  });

  testWidgets('tapping a light theme chip dispatches themeChanged', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    await tester.tap(find.text('Coffee'));

    verify(() => lightBloc.add(const ThemeLightEvent.themeChanged(themeId: 'kLCoffee'))).called(1);
  });

  testWidgets('the preference sheet changes the theme mode', (tester) async {
    await pumpPage(tester, ThemeMode.dark);

    await tester.tap(find.text('Theme Preference'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();

    verify(() => modeBloc.add(const ThemeModeEvent.modeChanged(mode: ThemeMode.light))).called(1);
    expect(find.text('Theme Preference'), findsOneWidget);
  });

  testWidgets('the selected accent is derived from the bloc state', (tester) async {
    when(() => lightBloc.state).thenReturn(
      ThemeLightState.initial().copyWith(
        theme: const ThemeLightEntity(themeId: 'kLRose', accentColorValue: 0xffff0000),
      ),
    );
    await pumpPage(tester, ThemeMode.light);

    final accent = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Accent colour 2 of 22');
    expect(tester.widget<Semantics>(accent).properties.selected, isTrue);
  });
}
