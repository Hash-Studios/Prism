import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/views/widgets/palette_swatch.dart';
import 'package:Prism/features/user_search/views/widgets/search_filter_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filter mapping', () {
    test('Any maps to no minimum', () {
      expect(minResolutionFor(shortSide: null, portraitOnly: true), isNull);
    });

    test('portrait asks for a 9:16 minimum', () {
      expect(minResolutionFor(shortSide: 1080, portraitOnly: true), '1080x1920');
      expect(minResolutionFor(shortSide: 1440, portraitOnly: true), '1440x2560');
      expect(minResolutionFor(shortSide: 2160, portraitOnly: true), '2160x3840');
    });

    test('without portrait only the shortest side is bounded', () {
      expect(minResolutionFor(shortSide: 1080, portraitOnly: false), '1080x1080');
    });

    test('reads the shortest side back from filters', () {
      expect(shortSideOf(const SearchFilters(minResolution: '1440x2560')), 1440);
      expect(shortSideOf(const SearchFilters(minResolution: '1920x1080')), 1080);
      expect(shortSideOf(const SearchFilters()), isNull);
    });

    test('builds filters from the sheet choices', () {
      final SearchFilters filters = buildSearchFilters(portraitOnly: true, shortSide: 1080, sort: SearchSort.latest);

      expect(filters.portraitOnly, isTrue);
      expect(filters.minResolution, '1080x1920');
      expect(filters.sort, SearchSort.latest);
    });
  });

  testWidgets('the sheet returns the chosen filters', (tester) async {
    SearchFilters? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showSearchFilterSheet(context, const SearchFilters()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1440p'));
    await tester.tap(find.text('Top'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(result, const SearchFilters(minResolution: '1440x2560', sort: SearchSort.toplist));
  });

  testWidgets('the Min resolution and Sort headings are 13 px w500, one step below the 14 px w600 chip labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        theme: withPrismChipTheme(ThemeData()),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSearchFilterSheet(context, const SearchFilters()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    TextStyle styleOf(String text) =>
        tester.widget<RichText>(find.descendant(of: find.text(text), matching: find.byType(RichText))).text.style!;
    for (final String heading in <String>['Min resolution', 'Sort']) {
      expect(styleOf(heading).fontSize, 13, reason: heading);
      expect(styleOf(heading).fontWeight, FontWeight.w500, reason: heading);
    }
    expect(styleOf('1440p').fontSize, 14);
    expect(styleOf('1440p').fontWeight, FontWeight.w600);
    expect(styleOf('Filters').fontSize, 20);
  });

  testWidgets('the sheet opens on the root navigator, above a nested tab navigator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => TextButton(
              onPressed: () => showSearchFilterSheet(context, const SearchFilters()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final NavigatorState root = tester.state<NavigatorState>(find.byType(Navigator).first);
    expect(ModalRoute.of(tester.element(find.text('Apply')))!.navigator, root);
  });

  group('colour', () {
    Future<void> openSheet(
      WidgetTester tester,
      SearchFilters initial,
      void Function(SearchFilters?) onResult, {
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(await showSearchFilterSheet(context, initial)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder swatch(String name) => find.bySemanticsLabel(name);

    testWidgets('shows twelve swatches, each with its colour name as the label', (tester) async {
      await openSheet(tester, const SearchFilters(), (_) {});

      for (final PrismPaletteColor entry in prismPalette) {
        expect(swatch(entry.name), findsOneWidget, reason: entry.id);
      }
      expect(find.byType(PaletteSwatch), findsNWidgets(12));
      expect(find.text('My accent'), findsOneWidget);
    });

    testWidgets('a tapped swatch is selected, and Apply returns it', (tester) async {
      SearchFilters? result;
      await openSheet(tester, const SearchFilters(), (value) => result = value);

      await tester.tap(swatch('Purple'));
      await tester.pump();
      expect(
        tester.widgetList<PaletteSwatch>(find.byType(PaletteSwatch)).where((s) => s.selected).single.color.id,
        'purple',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result, SearchFilters(color: paletteColorById('purple')));
    });

    testWidgets('only one colour is selected, and tapping it again clears it', (tester) async {
      SearchFilters? result;
      await openSheet(tester, const SearchFilters(), (value) => result = value);

      await tester.tap(swatch('Red'));
      await tester.pump();
      await tester.tap(swatch('Green'));
      await tester.pump();
      final selected = tester.widgetList<PaletteSwatch>(find.byType(PaletteSwatch)).where((s) => s.selected);
      expect(selected.map((s) => s.color.id), <String>['green']);

      await tester.tap(swatch('Green'));
      await tester.pump();
      expect(tester.widgetList<PaletteSwatch>(find.byType(PaletteSwatch)).where((s) => s.selected), isEmpty);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result!.color, isNull);
    });

    testWidgets('the sheet opens with the current colour selected', (tester) async {
      await openSheet(tester, SearchFilters(color: paletteColorById('teal')), (_) {});

      final selected = tester.widgetList<PaletteSwatch>(find.byType(PaletteSwatch)).where((s) => s.selected);
      expect(selected.map((s) => s.color.id), <String>['teal']);
    });

    testWidgets('My accent picks the palette colour nearest to the accent', (tester) async {
      SearchFilters? result;
      await openSheet(
        tester,
        const SearchFilters(),
        (value) => result = value,
        theme: ThemeData(colorScheme: const ColorScheme.light(primary: Color(0xFF1E88E5))),
      );

      await tester.tap(find.text('My accent'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result!.color!.id, 'blue');
    });

    testWidgets('Reset returns the default filters, with no colour', (tester) async {
      SearchFilters? result;
      await openSheet(tester, SearchFilters(color: paletteColorById('pink')), (value) => result = value);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(result, const SearchFilters());
    });

    test('buildSearchFilters carries the colour', () {
      final filters = buildSearchFilters(
        portraitOnly: true,
        shortSide: null,
        sort: SearchSort.relevance,
        color: paletteColorById('black'),
      );

      expect(filters.color!.id, 'black');
    });
  });

  group('depth', () {
    Future<void> openSheet(WidgetTester tester, SearchFilters initial, void Function(SearchFilters?) onResult) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(await showSearchFilterSheet(context, initial)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final Finder depthSwitch = find.widgetWithText(SwitchListTile, 'Depth Effect');

    test('the sheet choices carry the depth filter, and it is off unless asked for', () {
      expect(buildSearchFilters(portraitOnly: true, shortSide: null, sort: SearchSort.relevance).depthOnly, isFalse);
      expect(
        buildSearchFilters(portraitOnly: true, shortSide: null, sort: SearchSort.relevance, depthOnly: true),
        const SearchFilters(depthOnly: true),
      );
    });

    testWidgets('iOS shows the Depth Effect switch with its subtitle, and Apply returns the choice', (tester) async {
      SearchFilters? result;
      await openSheet(tester, const SearchFilters(), (picked) => result = picked);

      expect(depthSwitch, findsOneWidget);
      expect(find.text('Subject can sit in front of the clock'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(depthSwitch).value, isFalse);

      await tester.tap(depthSwitch);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(depthSwitch).value, isTrue);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result, const SearchFilters(depthOnly: true));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iOS opens with the switch on when the filter is on, and Reset clears it', (tester) async {
      SearchFilters? result;
      await openSheet(tester, const SearchFilters(depthOnly: true), (picked) => result = picked);

      expect(tester.widget<SwitchListTile>(depthSwitch).value, isTrue);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(result, const SearchFilters());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android does not show the Depth Effect switch', (tester) async {
      SearchFilters? result;
      await openSheet(tester, const SearchFilters(), (picked) => result = picked);

      expect(find.text('Depth Effect'), findsNothing);
      expect(find.text('Subject can sit in front of the clock'), findsNothing);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(result!.depthOnly, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
