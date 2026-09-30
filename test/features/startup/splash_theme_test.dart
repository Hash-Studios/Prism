import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockStartupBloc extends MockBloc<StartupEvent, StartupState> implements StartupBloc {}

const Map<String, Color> _themeBackgrounds = <String, Color>{
  'kLFrost White': Color(0xFFFFFFFF),
  'kLCoffee': Color(0xFFF7F1E3),
  'kLRose': Color(0xFFC5A79F),
  'kLCotton Blue': Color(0xFF8399BE),
  'kDMaterial Dark': Color(0xFF000000),
  'kDAMOLED': Color(0xFF000000),
  'kDOlive': Color(0xFF202113),
  'kDDeep Ocean': Color(0xFF041B29),
  'kDJungle': Color(0xFF12210E),
  'kDPepper': Color(0xFF290D02),
  'kDSky': Color(0xFF142431),
  'kDSteel': Color(0xFF393D46),
};

void main() {
  late _MockStartupBloc bloc;

  setUp(() {
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    bloc = _MockStartupBloc();
    when(() => bloc.state).thenReturn(StartupState.initial().copyWith(status: LoadStatus.loading));
  });

  tearDown(getIt.reset);

  Future<void> pumpSplash(WidgetTester tester, ThemeMode mode, ThemeData light, ThemeData dark) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        home: BlocProvider<StartupBloc>.value(value: bloc, child: const SplashWidget()),
      ),
    );
  }

  Color? splashColor(WidgetTester tester) => tester
      .widget<Container>(find.descendant(of: find.byType(SplashWidget), matching: find.byType(Container)).first)
      .color;

  for (final option in [...prismLightThemes, ...prismDarkThemes]) {
    testWidgets('splash uses ${option.label} even when the system brightness differs', (tester) async {
      final isLight = option.theme.brightness == Brightness.light;
      final expectedBackground = _themeBackgrounds[option.id]!;
      const accent = Color(0xFF123456);
      final theme = option.theme.copyWith(colorScheme: option.theme.colorScheme.copyWith(primary: accent));
      expect(theme.primaryColor, expectedBackground);
      expect(theme.colorScheme.primary, accent);
      tester.platformDispatcher.platformBrightnessTestValue = isLight ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpSplash(
        tester,
        isLight ? ThemeMode.light : ThemeMode.dark,
        isLight ? theme : prismLightThemes.first.theme,
        isLight ? prismDarkThemes.first.theme : theme,
      );

      expect(splashColor(tester), expectedBackground);
    });
  }

  testWidgets('system mode updates the splash when system brightness changes', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final light = prismLightThemes[1].theme;
    final dark = prismDarkThemes[2].theme;
    await pumpSplash(tester, ThemeMode.system, light, dark);
    expect(splashColor(tester), const Color(0xFFF7F1E3));

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(splashColor(tester), const Color(0xFF202113));
  });

  testWidgets('a theme update replaces the current splash background', (tester) async {
    final light = prismLightThemes.first.theme;
    final olive = prismDarkThemes[2].theme;
    final amoled = prismDarkThemes[1].theme;
    await pumpSplash(tester, ThemeMode.dark, light, olive);
    expect(splashColor(tester), const Color(0xFF202113));

    await pumpSplash(tester, ThemeMode.dark, light, amoled);
    await tester.pump(const Duration(milliseconds: 300));
    expect(splashColor(tester), const Color(0xFF000000));
  });

  testWidgets('retry returning to loading restores the themed splash', (tester) async {
    final states = StreamController<StartupState>();
    addTearDown(states.close);
    final failure = StartupState.initial().copyWith(status: LoadStatus.failure);
    whenListen(bloc, states.stream, initialState: failure);
    final theme = prismDarkThemes[2].theme;

    await pumpSplash(tester, ThemeMode.dark, prismLightThemes.first.theme, theme);
    expect(find.text("Prism couldn't start"), findsOneWidget);
    await tester.tap(find.text('Retry'));
    verify(() => bloc.add(StartupEvent.started(currentVersion: app_state.currentAppVersion))).called(1);

    states.add(StartupState.initial().copyWith(status: LoadStatus.loading));
    await tester.pump();
    // The splash cross-fades between its states.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Prism couldn't start"), findsNothing);
    expect(splashColor(tester), const Color(0xFF202113));
  });
}
