import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

void main() {
  late _MockThemeBloc themeBloc;

  setUpAll(() => registerFallbackValue(const ThemeEvent.started()));

  setUp(() async {
    themeBloc = _MockThemeBloc();
    when(() => themeBloc.state).thenReturn(ThemeState.initial());
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() => getIt.reset());

  Future<void> pumpPage(WidgetTester tester, ThemeMode mode, {ThemeState? state}) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => themeBloc.state).thenReturn((state ?? themeBloc.state).copyWith(mode: mode));
    await tester.pumpWidget(
      BlocProvider<ThemeBloc>.value(
        value: themeBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(),
          home: const ThemeView(),
        ),
      ),
    );
  }

  testWidgets('system mode shows the light and the dark pickers', (tester) async {
    await pumpPage(tester, ThemeMode.system);

    expect(find.text('Light themes'), findsOneWidget);
    expect(find.text('Dark themes'), findsOneWidget);
    expect(find.text('Light accent colour'), findsOneWidget);
    expect(find.text('Dark accent colour'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('light mode hides the dark pickers', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    expect(find.text('Light themes'), findsOneWidget);
    expect(find.text('Dark themes'), findsNothing);
    expect(find.text('Dark accent colour'), findsNothing);
  });

  testWidgets('every light and dark theme shows as a preview in its own colours', (tester) async {
    await pumpPage(tester, ThemeMode.system);

    final Map<String, List<PrismThemeOption>> grids = <String, List<PrismThemeOption>>{
      'theme-grid-light': prismLightThemes,
      'theme-grid-dark': prismDarkThemes,
    };
    for (final MapEntry<String, List<PrismThemeOption>> grid in grids.entries) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey<String>(grid.key)),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final Finder gridFinder = find.byKey(ValueKey<String>(grid.key));
      // The row scrolls sideways and builds only the cards near the screen, so check each theme as it comes into view.
      for (final PrismThemeOption option in grid.value) {
        final Finder name = find.descendant(
          of: gridFinder,
          matching: find.text(prismThemeDisplayName(option, AppLocalizationsEn())),
        );
        await tester.scrollUntilVisible(
          name,
          200,
          scrollable: find.descendant(of: gridFinder, matching: find.byType(Scrollable)),
        );
        expect(name, findsOneWidget);
        final Finder card = find.ancestor(of: name, matching: find.byType(SizedBox)).first;
        final PrismThemePreview preview = tester.widget<PrismThemePreview>(
          find.descendant(of: card, matching: find.byType(PrismThemePreview)),
        );
        expect(preview.theme.colorScheme.surface, option.theme.colorScheme.surface);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selected theme has an accent ring and a check badge', (tester) async {
    const Color accent = Color(0xff123456);
    final ThemeData light = ThemeData.light();
    final ThemeData hostTheme = light.copyWith(colorScheme: light.colorScheme.copyWith(primary: accent));
    await tester.pumpWidget(
      BlocProvider<ThemeBloc>.value(
        value: themeBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: hostTheme,
          home: const ThemeView(),
        ),
      ),
    );

    final Finder selected = find.byWidgetPredicate(
      (widget) =>
          widget is AnimatedContainer &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).border!.top.color == accent,
    );
    expect(selected, findsNWidgets(2), reason: 'system mode shows two grids, each with one selected theme');
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
  });

  testWidgets('tapping a light theme chip dispatches themeChanged', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    await tester.tap(find.text('Coffee'));

    verify(() => themeBloc.add(const ThemeEvent.lightThemeChanged(themeId: 'kLCoffee'))).called(1);
  });

  testWidgets('the mode control changes the theme mode', (tester) async {
    await pumpPage(tester, ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await tester.pump();

    verify(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.light))).called(1);
  });

  testWidgets('the mode control exposes each mode and its selection to accessibility', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpPage(tester, ThemeMode.dark);

    expect(tester.getSemantics(find.text('Dark')), isSemantics(label: 'Dark', isButton: true, isSelected: true));
    expect(
      tester.getSemantics(find.text('Light')),
      isSemantics(label: 'Light', isButton: true, isSelected: false, hasTapAction: true),
    );
    handle.dispose();
  });

  for (final Size size in const <Size>[Size(320, 568), Size(568, 320)]) {
    testWidgets('the mode control remains usable with large text at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        BlocProvider<ThemeBloc>.value(
          value: themeBloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const ThemeView(),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Dark'));
      await tester.pump();

      verify(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.dark))).called(1);
    });
  }

  testWidgets('the selected accent is derived from the bloc state', (tester) async {
    when(() => themeBloc.state).thenReturn(
      ThemeState.initial().copyWith(light: const ThemeSelection(themeId: 'kLRose', accentColorValue: 0xffff0000)),
    );
    await pumpPage(tester, ThemeMode.light);

    final accent = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Accent colour 2 of 22');
    expect(tester.widget<Semantics>(accent).properties.selected, isTrue);
  });

  testWidgets('accent targets stay at least 44 points tall on a short screen and remain selectable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final SemanticsHandle semantics = tester.ensureSemantics();
    when(() => themeBloc.state).thenReturn(themeBloc.state.copyWith(mode: ThemeMode.light));
    await tester.pumpWidget(
      BlocProvider<ThemeBloc>.value(
        value: themeBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(),
          home: const ThemeView(),
        ),
      ),
    );

    final Finder accent = find.bySemanticsLabel('Accent colour 2 of 22');
    await tester.ensureVisible(accent);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getBottomRight(accent) - const Offset(4, 4));
    await tester.pump();
    final Rect targetBounds = tester.getSemantics(accent).rect;
    semantics.dispose();

    verify(() => themeBloc.add(const ThemeEvent.lightAccentChanged(accentColorValue: 0xFFFF0000))).called(1);
    expect(targetBounds.width, greaterThanOrEqualTo(44));
    expect(targetBounds.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rendered selectable accents stay readable across the themes', (tester) async {
    await pumpPage(tester, ThemeMode.light);
    final Finder choices = find.byWidgetPredicate(
      (widget) => widget is Semantics && (widget.properties.label?.startsWith('Accent colour ') ?? false),
    );
    final Set<Color> picks = <Color>{};
    for (final Element choice in choices.evaluate()) {
      final Finder dot = find.descendant(
        of: find.byWidget(choice.widget),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.key is ValueKey<String> && widget.decoration is BoxDecoration,
        ),
      );
      picks.add((tester.widget<Container>(dot).decoration! as BoxDecoration).color!);
    }
    expect(picks, isNotEmpty);

    for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
      for (final Color pick in picks) {
        final ThemeData theme = withPrismAccent(option.theme, pick.toARGB32());
        final ColorScheme scheme = theme.colorScheme;
        expect(
          contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: 'onPrimary on $pick in ${prismThemeDisplayName(option, AppLocalizationsEn())}',
        );
        expect(
          contrastRatio(scheme.onError, scheme.error),
          greaterThanOrEqualTo(4.5),
          reason: 'onError on $pick in ${prismThemeDisplayName(option, AppLocalizationsEn())}',
        );
        expect(
          contrastRatio(scheme.primary, theme.primaryColor),
          greaterThanOrEqualTo(1.5),
          reason: '$pick against the ${prismThemeDisplayName(option, AppLocalizationsEn())} background',
        );
      }
    }
  });

  testWidgets('the title reads Themes and changes apply live without a Done button', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    expect(find.text('Themes'), findsOneWidget);
    expect(find.byTooltip('Done'), findsNothing);
  });

  testWidgets('the system colour switch is hidden when the phone has no system accent', (tester) async {
    await pumpPage(tester, ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text('Match system colour'), findsNothing);
  });

  testWidgets('the custom accent circle is labelled Custom color', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Custom color'), findsOneWidget);
  });

  testWidgets('tapping the custom accent circle opens the custom colour sheet', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Custom color'));
    await tester.pumpAndSettle();

    expect(find.text('Use color'), findsOneWidget);
  });

  testWidgets('a hex picked in the custom colour sheet becomes the light accent', (tester) async {
    await pumpPage(tester, ThemeMode.light);
    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Custom color'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '#1976D2');
    await tester.pump();
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();

    verify(() => themeBloc.add(const ThemeEvent.lightAccentChanged(accentColorValue: 0xFF1976D2))).called(1);
  });

  testWidgets('a custom light accent that is not a swatch marks the custom circle selected', (tester) async {
    when(() => themeBloc.state).thenReturn(
      ThemeState.initial().copyWith(light: const ThemeSelection(themeId: 'kLRose', accentColorValue: 0xFF123456)),
    );
    await pumpPage(tester, ThemeMode.light);

    final Semantics custom = tester.widget<Semantics>(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Custom color'),
    );
    expect(custom.properties.selected, isTrue);
  });

  group('Material You', () {
    final SystemColorSchemes schemes = SystemColorSchemes(
      light: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
      dark: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC), brightness: Brightness.dark),
    );

    testWidgets('Material You leads both lists on Android 12+', (tester) async {
      await pumpPage(tester, ThemeMode.system, state: ThemeState.initial().copyWith(system: schemes));

      expect(find.text('Material You'), findsNWidgets(2));
      final Finder lightRow = find.byKey(const ValueKey<String>('theme-grid-light'));
      final Finder lightMaterialYou = find.descendant(of: lightRow, matching: find.text('Material You'));
      final Finder lightFrost = find.descendant(of: lightRow, matching: find.text('Frost White'));
      expect(tester.getTopLeft(lightMaterialYou).dx, lessThan(tester.getTopLeft(lightFrost).dx));

      final Finder darkRow = find.byKey(const ValueKey<String>('theme-grid-dark'));
      expect(find.descendant(of: darkRow, matching: find.text('Material You')), findsOneWidget);
    });

    testWidgets('no Material You below Android 12 and on iOS', (tester) async {
      await pumpPage(tester, ThemeMode.system);

      expect(find.text('Material You'), findsNothing);
    });

    testWidgets('Material You hides the accent controls for its slot', (tester) async {
      await pumpPage(
        tester,
        ThemeMode.light,
        state: ThemeState.initial().copyWith(
          light: const ThemeSelection(themeId: prismMaterialYouLightThemeId, accentColorValue: prismDefaultAccentValue),
          system: schemes,
        ),
      );

      expect(find.text('Light accent colour'), findsNothing);
      expect(find.text('Material You takes its colours from your wallpaper.'), findsOneWidget);
      expect(find.byType(PrismSwitchRow), findsNothing);
    });

    testWidgets('an unusable Material You id shows the default theme and its accent controls', (tester) async {
      await pumpPage(
        tester,
        ThemeMode.light,
        state: ThemeState.initial().copyWith(
          light: const ThemeSelection(themeId: prismMaterialYouLightThemeId, accentColorValue: prismDefaultAccentValue),
        ),
      );

      expect(find.text('Light accent colour'), findsOneWidget);
      expect(find.text('Material You takes its colours from your wallpaper.'), findsNothing);
    });

    testWidgets('mixed slots hide only the Material You accent', (tester) async {
      await pumpPage(
        tester,
        ThemeMode.system,
        state: ThemeState.initial().copyWith(
          light: const ThemeSelection(themeId: prismMaterialYouLightThemeId, accentColorValue: prismDefaultAccentValue),
          dark: const ThemeSelection(themeId: prismAmoledDarkThemeId, accentColorValue: prismDefaultAccentValue),
          system: schemes,
        ),
      );

      expect(find.text('Light accent colour'), findsNothing);
      expect(find.text('Dark accent colour'), findsOneWidget);
      expect(find.text('Material You takes its colours from your wallpaper.'), findsOneWidget);
    });

    testWidgets('tapping the Material You chip dispatches lightThemeChanged', (tester) async {
      await pumpPage(tester, ThemeMode.light, state: ThemeState.initial().copyWith(system: schemes));

      await tester.tap(find.text('Material You'));

      verify(() => themeBloc.add(const ThemeEvent.lightThemeChanged(themeId: prismMaterialYouLightThemeId))).called(1);
    });
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

      await tester.scrollUntilVisible(find.text('Match system colour'), 300, scrollable: find.byType(Scrollable).first);
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

      await tester.scrollUntilVisible(find.text('Match system colour'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Match system colour'));
      await tester.pumpAndSettle();

      expect(settings.get<bool>(SystemAccentChannel.settingsKey, defaultValue: true), isFalse);
      verifyNever(() => themeBloc.add(any()));
    });

    testWidgets('picking an accent by hand turns the switch off', (tester) async {
      await settings.set(SystemAccentChannel.settingsKey, true);
      await pumpPage(tester, ThemeMode.light);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.bySemanticsLabel('Accent colour 2 of 22'));
      await tester.tap(find.bySemanticsLabel('Accent colour 2 of 22'));
      await tester.pumpAndSettle();

      expect(settings.get<bool>(SystemAccentChannel.settingsKey, defaultValue: true), isFalse);
      verify(() => themeBloc.add(const ThemeEvent.lightAccentChanged(accentColorValue: 0xFFFF0000))).called(1);
    });
  });
}
