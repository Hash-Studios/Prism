import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/user_search/data/search_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the tags are the classifier names, then AMOLED and Cityscape, with no repeats', () {
    expect(curatedSearchTags.take(prismClassifierCategories.length).toSet(), prismClassifierCategories);
    expect(curatedSearchTags.skip(prismClassifierCategories.length), <String>['AMOLED', 'Cityscape']);
    expect(curatedSearchTags.toSet(), hasLength(curatedSearchTags.length));
    expect(curatedSearchTags, contains('Minimal'));
    expect(curatedSearchTags, contains('Gaming'));
    expect(curatedSearchTags.where((tag) => tag == 'Pastel'), hasLength(1));
  });
}
