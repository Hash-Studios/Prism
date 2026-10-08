import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

void main() {
  late _MockThemeBloc themeBloc;

  setUpAll(() => registerFallbackValue(const ThemeEvent.started()));

  setUp(() {
    themeBloc = _MockThemeBloc();
    when(() => themeBloc.state).thenReturn(ThemeState.initial());
  });

  Future<void> pumpPage(WidgetTester tester, ThemeMode mode) async {
    tester.view.physicalSize = const Size(1000, 1400);
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

    verify(() => themeBloc.add(const ThemeEvent.lightThemeChanged(themeId: 'kLCoffee'))).called(1);
  });

  testWidgets('the preference sheet changes the theme mode', (tester) async {
    await pumpPage(tester, ThemeMode.dark);

    await tester.tap(find.text('Theme Preference'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();

    verify(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.light))).called(1);
    expect(find.text('Theme Preference'), findsOneWidget);
  });

  testWidgets('the selected accent is derived from the bloc state', (tester) async {
    when(() => themeBloc.state).thenReturn(
      ThemeState.initial().copyWith(light: const ThemeSelection(themeId: 'kLRose', accentColorValue: 0xffff0000)),
    );
    await pumpPage(tester, ThemeMode.light);

    final accent = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Accent colour 2 of 22');
    expect(tester.widget<Semantics>(accent).properties.selected, isTrue);
  });

  testWidgets('the title reads Themes and the page has no beta badge', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    expect(find.text('Themes'), findsOneWidget);
    expect(find.text('Theme Manager'), findsNothing);
    expect(find.text('BETA'), findsNothing);
    expect(find.byTooltip('Done'), findsOneWidget);
  });

  testWidgets('the system colour switch is hidden when the phone has no system accent', (tester) async {
    await pumpPage(tester, ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text('Match system colour'), findsNothing);
  });

  group('match system colour', () {
    const MethodChannel channel = MethodChannel('prism/system_colors');
    late SettingsLocalDataSource settings;

    setUp(() async {
      settings = SettingsLocalDataSource(InMemoryLocalStore());
      await getIt.reset();
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'accent');
        return <String, Object?>{'light': 0xFF336699, 'dark': 0xFF99CCFF};
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await getIt.reset();
    });

    testWidgets('turning it on stores the flag and sets both accents', (tester) async {
      await pumpPage(tester, ThemeMode.system);
      await tester.pumpAndSettle();

      expect(find.text('Match system colour'), findsOneWidget);
      await tester.tap(find.text('Match system colour'));
      await tester.pumpAndSettle();

      expect(settings.get<bool>(SystemAccentChannel.settingsKey, defaultValue: false), isTrue);
      verify(() => themeBloc.add(const ThemeEvent.lightAccentChanged(accentColorValue: 0xFF336699))).called(1);
      verify(() => themeBloc.add(const ThemeEvent.darkAccentChanged(accentColorValue: 0xFF99CCFF))).called(1);
    });

    testWidgets('turning it off leaves the stored accents alone', (tester) async {
      await settings.set(SystemAccentChannel.settingsKey, true);
      when(() => themeBloc.state).thenReturn(
        ThemeState.initial().copyWith(
          light: const ThemeSelection(themeId: 'kLRose', accentColorValue: 0xFF336699),
          dark: const ThemeSelection(themeId: 'kDMaterial Dark', accentColorValue: 0xFF99CCFF),
        ),
      );
      await pumpPage(tester, ThemeMode.system);
      await tester.pumpAndSettle();
      clearInteractions(themeBloc);

      await tester.tap(find.text('Match system colour'));
      await tester.pumpAndSettle();

      expect(settings.get<bool>(SystemAccentChannel.settingsKey, defaultValue: true), isFalse);
      verifyNever(() => themeBloc.add(any()));
    });

    testWidgets('picking an accent by hand turns the switch off', (tester) async {
      await settings.set(SystemAccentChannel.settingsKey, true);
      await pumpPage(tester, ThemeMode.light);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Accent colour 2 of 22'));
      await tester.pumpAndSettle();

      expect(settings.get<bool>(SystemAccentChannel.settingsKey, defaultValue: true), isFalse);
      verify(() => themeBloc.add(const ThemeEvent.lightAccentChanged(accentColorValue: 0xFFFF0000))).called(1);
    });
  });
}
