import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => pendingSearch.value = null);
  tearDown(() => pendingSearch.value = null);

  group('round trip', () {
    final List<(String, SearchFilters)> cases = <(String, SearchFilters)>[
      ('default filters', const SearchFilters()),
      ('live kind', SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live})),
      (
        'desktop and light-dark kinds, Prism only',
        SearchFilters(
          kinds: <PrismWallKind>{PrismWallKind.desktop, PrismWallKind.lightDark},
          source: SearchSource.prism,
        ),
      ),
      (
        'live kind with colour, resolution and sort',
        SearchFilters(
          kinds: <PrismWallKind>{PrismWallKind.live},
          color: paletteColorById('blue'),
          minResolution: '1080x1920',
          portraitOnly: false,
          sort: SearchSort.toplist,
        ),
      ),
      ('depth only', const SearchFilters(depthOnly: true)),
      ('spatial only', const SearchFilters(spatialOnly: true)),
    ];

    for (final String query in <String>['sky', '']) {
      for (final (String name, SearchFilters filters) in cases) {
        test('$name keeps its filters and query "$query" through a link', () {
          final String path = searchLinkPath(filters.toLink(query));

          final DeepLinkRouteMatch? match = DeepLinkRouteCatalog.match(Uri.parse(path));
          expect(match?.target, DeepLinkPageTarget.searchTab);

          final SearchLinkFields? fields = parseSearchLink(match!.queryParams);
          expect(fields, isNotNull);
          expect(fields!.query, query);
          expect(SearchFilters.fromLink(fields), filters);
        });
      }
    }
  });

  group('literal links', () {
    test('a query with default filters is q only', () {
      expect(searchLinkPath(const SearchFilters().toLink('sky')), '/dashboard/search?q=sky');
    });

    test('kinds are comma separated in kind order, and the comma is encoded', () {
      expect(
        searchLinkPath(
          SearchFilters(kinds: <PrismWallKind>{PrismWallKind.lightDark, PrismWallKind.live}).toLink('sky'),
        ),
        '/dashboard/search?q=sky&kind=live%2Clight-dark',
      );
    });

    test('an empty query with default filters is the bare path', () {
      expect(searchLinkPath(const SearchFilters().toLink('')), '/dashboard/search');
    });
  });

  group('links that open Search', () {
    test('the bare path matches the search tab with no query keys', () {
      final DeepLinkRouteMatch? match = DeepLinkRouteCatalog.match(Uri.parse('/dashboard/search'));

      expect(match?.target, DeepLinkPageTarget.searchTab);
      expect(match?.queryParams, isEmpty);
    });

    test('the bare path opens Search and queues no search', () async {
      final route = await routeForPageLink(
        const PageLinkIntent(path: '/dashboard/search', rawUri: '/dashboard/search'),
      );

      expect(route, isA<DashboardRoute>());
      expect(pendingSearch.value, isNull);
    });

    test('a link with search keys queues its query and filters', () async {
      await routeForPageLink(
        const PageLinkIntent(path: '/dashboard/search?q=sky&kind=live', rawUri: '/dashboard/search?q=sky&kind=live'),
      );

      expect(pendingSearch.value, (query: 'sky', filters: SearchFilters(kinds: <PrismWallKind>{PrismWallKind.live})));
    });

    test('an unknown palette colour matches the catalog but queues no search', () async {
      expect(
        DeepLinkRouteCatalog.match(Uri.parse('/dashboard/search?color=zzzz'))?.target,
        DeepLinkPageTarget.searchTab,
      );

      final route = await routeForPageLink(
        const PageLinkIntent(path: '/dashboard/search?color=zzzz', rawUri: '/dashboard/search?color=zzzz'),
      );

      expect(route, isA<DashboardRoute>());
      expect(pendingSearch.value, isNull);
    });

    test('utm keys are still allowed next to search keys', () {
      expect(
        DeepLinkRouteCatalog.match(Uri.parse('/dashboard/search?q=sky&utm_source=x'))?.target,
        DeepLinkPageTarget.searchTab,
      );
    });
  });

  group('invalid links', () {
    test('the catalog refuses a link with a bad value or an unknown key', () {
      final List<String> invalid = <String>[
        '/dashboard/search?kind=video',
        '/dashboard/search?source=pexels',
        '/dashboard/search?sort=random',
        '/dashboard/search?res=big',
        '/dashboard/search?portrait=yes',
        '/dashboard/search?color=Blue1',
        '/dashboard/search?q=${'a' * 201}',
        '/dashboard/search?foo=1',
      ];

      for (final String path in invalid) {
        expect(DeepLinkRouteCatalog.match(Uri.parse(path)), isNull, reason: path);
      }
    });
  });
}
