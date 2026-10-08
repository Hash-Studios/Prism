import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/views/widgets/search_filter_sheet.dart';
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

  testWidgets('the sheet opens on the root navigator, above a nested tab navigator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
}
