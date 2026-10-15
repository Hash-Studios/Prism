import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are portrait only, no minimum and relevance sort', () {
    const filters = SearchFilters();

    expect(filters.portraitOnly, isTrue);
    expect(filters.minResolution, isNull);
    expect(filters.sort, SearchSort.relevance);
    expect(filters.wallhavenSorting, isNull);
  });

  test('sort maps to the Wallhaven sorting value', () {
    expect(const SearchFilters(sort: SearchSort.latest).wallhavenSorting, 'date_added');
    expect(const SearchFilters(sort: SearchSort.toplist).wallhavenSorting, 'toplist');
  });

  test('acceptsResolution checks orientation and minimum, and lets unknown sizes through', () {
    const filters = SearchFilters(minResolution: '1080x1920');

    expect(filters.acceptsResolution('1440x2560'), isTrue);
    expect(filters.acceptsResolution('720x1280'), isFalse);
    expect(filters.acceptsResolution('3840x2160'), isFalse, reason: 'landscape');
    expect(filters.acceptsResolution(null), isTrue);
    expect(filters.acceptsResolution('big'), isTrue);
    expect(const SearchFilters(portraitOnly: false).acceptsResolution('3840x2160'), isTrue);
  });

  test('copyWith can clear the minimum resolution, and equal filters compare equal', () {
    final filters = const SearchFilters().copyWith(minResolution: '2160x3840', sort: SearchSort.latest);

    expect(filters.minResolution, '2160x3840');
    expect(filters.copyWith(clearMinResolution: true).minResolution, isNull);
    expect(const SearchFilters(), const SearchFilters());
    expect(const SearchFilters().hashCode, const SearchFilters().hashCode);
    expect(filters, isNot(const SearchFilters()));
  });
}
