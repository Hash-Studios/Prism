import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

void main() {
  late _MockThemeBloc themeBloc;

  setUp(() {
    themeBloc = _MockThemeBloc();
    when(() => themeBloc.state).thenReturn(ThemeState.initial());
  });

  Future<void> pumpPage(WidgetTester tester, ThemeMode mode) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => themeBloc.state).thenReturn(themeBloc.state.copyWith(mode: mode));
    await tester.pumpWidget(
      BlocProvider<ThemeBloc>.value(
        value: themeBloc,
        child: MaterialApp(theme: ThemeData.light(), home: const ThemeView()),
      ),
    );
  }

  testWidgets('system mode shows the light and the dark pickers', (tester) async {
    await pumpPage(tester, ThemeMode.system);

    expect(find.text('Themes'), findsOneWidget);
    expect(find.text('BETA'), findsNothing);
    expect(find.text('Light themes'), findsOneWidget);
    expect(find.text('Dark themes'), findsOneWidget);
    expect(find.text('Light accent'), findsOneWidget);
    expect(find.text('Dark accent'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.byTooltip('Apply theme'), findsOneWidget);
  });

  testWidgets('light mode hides the dark pickers', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    expect(find.text('Light themes'), findsOneWidget);
    expect(find.text('Dark themes'), findsNothing);
    expect(find.text('Accent colour'), findsOneWidget);
    expect(find.text('Dark accent'), findsNothing);
  });

  testWidgets('tapping a light theme swatch dispatches themeChanged', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    await tester.tap(find.text('Coffee'));

    verify(() => themeBloc.add(const ThemeEvent.lightThemeChanged(themeId: 'kLCoffee'))).called(1);
  });

  testWidgets('the mode control changes the theme mode', (tester) async {
    await pumpPage(tester, ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    verify(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.light))).called(1);
  });

  testWidgets('the selected theme swatch is marked selected', (tester) async {
    when(() => themeBloc.state).thenReturn(
      ThemeState.initial().copyWith(light: const ThemeSelection(themeId: 'kLRose', accentColorValue: 0xffe57697)),
    );
    await pumpPage(tester, ThemeMode.light);

    final rose = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Rose theme');
    expect(tester.widget<Semantics>(rose).properties.selected, isTrue);
  });

  testWidgets('the selected accent is derived from the bloc state', (tester) async {
    when(() => themeBloc.state).thenReturn(
      ThemeState.initial().copyWith(light: const ThemeSelection(themeId: 'kLRose', accentColorValue: 0xffff0000)),
    );
    await pumpPage(tester, ThemeMode.light);

    final accent = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Accent colour 2 of 22');
    expect(tester.widget<Semantics>(accent).properties.selected, isTrue);
  });
}
