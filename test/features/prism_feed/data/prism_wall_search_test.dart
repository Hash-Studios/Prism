import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/prism_feed/data/prism_wall_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';

void main() {
  late FakeFirestoreClient firestore;
  late PrismWallSearch search;

  setUp(() {
    firestore = FakeFirestoreClient();
    search = PrismWallSearch(firestore, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
  });

  List<Object?> valuesOf(String sourceTag) =>
      firestore.querySpecs.firstWhere((spec) => spec.sourceTag == sourceTag).filters.last.value! as List<Object?>;

  test('a one word query keeps the three spellings it always had', () async {
    await search.search('forest');

    expect(valuesOf('PrismWallSearch.tags'), <String>['forest', 'Forest']);
    expect(
      firestore.querySpecs.firstWhere((spec) => spec.sourceTag == 'PrismWallSearch.tags').filters.last.op,
      FirestoreFilterOp.arrayContainsAny,
    );
  });

  test('each word of a longer query is a tag, so "dark blue forest" can match a wall tagged "forest"', () async {
    await search.search('dark blue forest');

    final List<Object?> tags = valuesOf('PrismWallSearch.tags');
    expect(tags, containsAll(<String>['dark', 'Dark', 'blue', 'Blue', 'forest', 'Forest']));
    expect(tags, contains('dark blue forest'));
  });

  test('the tag filter never passes more than 30 values, and uses at most 10 words', () async {
    await search.search(List<String>.generate(14, (i) => 'word$i').join(' '));

    final List<Object?> tags = valuesOf('PrismWallSearch.tags');
    expect(tags.length, lessThanOrEqualTo(30));
    expect(tags, contains('word9'));
    expect(tags, isNot(contains('word10')));
  });

  test('a category name inside a longer query matches the category field', () async {
    await search.search('dark forest');

    expect(valuesOf('PrismWallSearch.category'), containsAll(<String>['Dark', 'Forest']));
  });

  test('repeated and extra spaces never make an empty tag', () async {
    await search.search('  neon   neon  city ');

    final List<Object?> tags = valuesOf('PrismWallSearch.tags');
    expect(tags, isNot(contains('')));
    expect(tags.where((tag) => tag == 'neon'), hasLength(1));
  });
}
