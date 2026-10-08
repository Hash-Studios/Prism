import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/user_search/data/search_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the tags are the 18 classifier names, then AMOLED, Pastel and Cityscape, with no repeats', () {
    expect(curatedSearchTags.take(18).toSet(), prismClassifierCategories);
    expect(curatedSearchTags.skip(18), <String>['AMOLED', 'Pastel', 'Cityscape']);
    expect(curatedSearchTags.toSet(), hasLength(curatedSearchTags.length));
    expect(curatedSearchTags, contains('Minimal'));
  });

  test('the order never changes between reads', () {
    expect(curatedSearchTags, orderedEquals(List<String>.of(curatedSearchTags)));
    expect(curatedSearchTags.first, 'Nature');
  });
}
