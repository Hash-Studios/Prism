import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
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

  Future<void> pumpPage(WidgetTester tester, ThemeMode mode) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => themeBloc.state).thenReturn(themeBloc.state.copyWith(mode: mode));
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

  testWidgets('all light and dark theme chips use their scheme surface and readable text roles', (tester) async {
    await pumpPage(tester, ThemeMode.system);

    final List<List<PrismThemeOption>> themeGroups = <List<PrismThemeOption>>[prismLightThemes, prismDarkThemes];
    for (int rowIndex = 0; rowIndex < themeGroups.length; rowIndex++) {
      final Finder row = find.byType(ListView).at(rowIndex);
      final Finder scrollable = find.descendant(of: row, matching: find.byType(Scrollable));
      for (final PrismThemeOption option in themeGroups[rowIndex]) {
        await tester.scrollUntilVisible(
          find.text(prismThemeDisplayName(option, AppLocalizationsEn())),
          200,
          scrollable: scrollable,
        );

        final Text label = tester.widget<Text>(find.text(prismThemeDisplayName(option, AppLocalizationsEn())));
        expect(label.style!.color, option.theme.colorScheme.onSurface);
        expect(
          contrastRatio(option.theme.colorScheme.onSurface, option.theme.colorScheme.surfaceContainerHigh),
          greaterThanOrEqualTo(4.5),
          reason: '${prismThemeDisplayName(option, AppLocalizationsEn())} label must be readable against its chip fill',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${prismThemeDisplayName(option, AppLocalizationsEn())} chip must fit its row',
        );
      }
    }
  });

  testWidgets('theme manager chip borders and preview shadows follow the active scheme', (tester) async {
    const Color shadow = Color(0xff123456);
    final ThemeData light = ThemeData.light();
    final ThemeData hostTheme = light.copyWith(colorScheme: light.colorScheme.copyWith(shadow: shadow));
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

    final Finder preview = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          ((widget.decoration! as BoxDecoration).boxShadow?.isNotEmpty ?? false),
    );
    final BoxDecoration previewDecoration = tester.widget<Container>(preview.first).decoration! as BoxDecoration;
    expect(previewDecoration.boxShadow!.first.color, shadow.withValues(alpha: 0.15));

    final Finder label = find.text(prismThemeDisplayName(prismLightThemes.first, AppLocalizationsEn()));
    final Finder chip = find.ancestor(of: label, matching: find.byType(Container)).first;
    final BoxDecoration chipDecoration = tester.widget<Container>(chip).decoration! as BoxDecoration;
    expect(chipDecoration.border!.top.color, prismLightThemes.first.theme.colorScheme.scrim.withValues(alpha: 0.12));
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

  testWidgets('the preference sheet marks the selected mode with the accent, not the error red', (tester) async {
    await pumpPage(tester, ThemeMode.dark);

    await tester.tap(find.text('Theme Preference'));
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(tester.element(find.text('Dark').last)).colorScheme;
    final Finder option = find.ancestor(of: find.text('Dark').last, matching: find.byType(Container)).first;
    final BoxDecoration selected = tester.widget<Container>(option).decoration! as BoxDecoration;
    expect(selected.border!.top.color, scheme.primary);
    expect(selected.border!.top.color, isNot(scheme.error));
  });

  testWidgets('the preference sheet exposes each mode and its selection to accessibility', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpPage(tester, ThemeMode.dark);

    await tester.tap(find.text('Theme Preference'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Dark').last),
      isSemantics(label: 'Dark', isButton: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.text('Light').last),
      isSemantics(label: 'Light', isButton: true, isSelected: false, hasTapAction: true),
    );
    final SemanticsNode light = tester.getSemantics(find.text('Light').last);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: light.id),
    );
    await tester.pumpAndSettle();
    verify(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.light))).called(1);
    expect(find.text('Theme Preference'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the preference sheet remains usable with large text on a short screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
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

    await tester.tap(find.text('Theme Preference'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Dark').last);
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    verify(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.dark))).called(1);
  });

  testWidgets('the preference sheet remains usable with large text in landscape', (tester) async {
    tester.view.physicalSize = const Size(568, 320);
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

    await tester.tap(find.text('Theme Preference'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Dark').last);
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    verify(() => themeBloc.add(const ThemeEvent.modeChanged(mode: ThemeMode.dark))).called(1);
  });

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
    final Finder picker = find.ancestor(of: choices.first, matching: find.byType(ListView));
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(of: picker, matching: find.byType(Scrollable)),
    );

    while (true) {
      for (final Element choice in choices.evaluate()) {
        final Finder swatch = find.descendant(
          of: find.byWidget(choice.widget),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).border != null,
          ),
        );
        final BoxDecoration decoration = tester.widget<Container>(swatch).decoration! as BoxDecoration;
        picks.add(decoration.color!);
      }
      if (scrollable.position.pixels >= scrollable.position.maxScrollExtent) break;
      final double previousOffset = scrollable.position.pixels;
      scrollable.position.jumpTo(
        (previousOffset + scrollable.position.viewportDimension).clamp(0, scrollable.position.maxScrollExtent),
      );
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(previousOffset), reason: 'the picker must advance to its end');
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

  testWidgets('the title reads Themes and the Done button is available', (tester) async {
    await pumpPage(tester, ThemeMode.light);

    expect(find.text('Themes'), findsOneWidget);
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
