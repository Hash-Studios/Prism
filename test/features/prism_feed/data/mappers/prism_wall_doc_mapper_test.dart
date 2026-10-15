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

  group('title', () {
    test('survives the JSON round trip', () {
      final PrismWallDocDto parsed = PrismWallDocDto.fromJson(<String, dynamic>{
        'wallpaper_url': 'https://x/y.jpg',
        'title': ' Night city ',
      });
      expect(PrismWallDocDto.fromJson(parsed.toJson()).title, ' Night city ');
      expect(parsed.toDomain(docId: 'a').title, 'Night city');
    });

    test('is null when the document has none or a blank one', () {
      expect(PrismWallDocDto.fromJson(<String, dynamic>{'wallpaper_url': 'https://x/y.jpg'}).title, isNull);
      expect(const PrismWallDocDto(wallpaperUrl: 'https://x/y.jpg', title: '  ').toDomain(docId: 'a').title, isNull);
      expect(dto().toDomain(docId: 'a').title, isNull);
    });
  });
}
