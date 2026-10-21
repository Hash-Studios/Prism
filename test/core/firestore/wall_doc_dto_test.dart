import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category and description remain separate through Firestore JSON round trip', () {
    final dto = WallDocDto.fromJson(<String, dynamic>{
      'id': 'lake',
      'category': 'Nature',
      'desc': 'A lake at dawn',
      'wallpaper_url': 'https://x/lake',
    });
    final restored = WallDocDto.fromJson(dto.toJson());
    expect(restored.category, 'Nature');
    expect(restored.desc, 'A lake at dawn');
  });

  test('legacy or null categories stay absent and never fall back to description', () {
    for (final json in <Map<String, dynamic>>[
      <String, dynamic>{'desc': 'A lake at dawn'},
      <String, dynamic>{'category': null, 'desc': 'A lake at dawn'},
    ]) {
      expect(WallDocDto.fromJson(json).category, isEmpty);
    }
  });
}
