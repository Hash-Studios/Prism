import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
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
      tester.platformDispatcher.platformBrightnessTestValue = isLight ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpSplash(
        tester,
        isLight ? ThemeMode.light : ThemeMode.dark,
        isLight ? option.theme : prismLightThemes.first.theme,
        isLight ? prismDarkThemes.first.theme : option.theme,
      );

      expect(splashColor(tester), option.theme.primaryColor);
    });
  }

  testWidgets('system mode updates the splash when system brightness changes', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final light = prismLightThemes[1].theme;
    final dark = prismDarkThemes[2].theme;
    await pumpSplash(tester, ThemeMode.system, light, dark);
    expect(splashColor(tester), light.primaryColor);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(splashColor(tester), dark.primaryColor);
  });
}
