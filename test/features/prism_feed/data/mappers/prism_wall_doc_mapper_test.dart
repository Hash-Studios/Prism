import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PrismWallDocDto dto({String category = '', List<String> tags = const <String>[]}) =>
      PrismWallDocDto(wallpaperUrl: 'https://x/y.jpg', category: category, tags: tags);

  test('merges AI category into tags', () {
    expect(dto(category: 'Space', tags: <String>['stars']).toDomain(docId: 'a').tags, <String>['stars', 'Space']);
  });

  test('General category leaves tags as-is', () {
    expect(dto(category: 'General', tags: <String>['stars']).toDomain(docId: 'a').tags, <String>['stars']);
    expect(dto(category: 'General').toDomain(docId: 'a').tags, isNull);
  });

  test('de-duplicates case-insensitively', () {
    expect(dto(category: 'space', tags: <String>['Space']).toDomain(docId: 'a').tags, <String>['Space']);
  });
}
