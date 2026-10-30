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

  test('missing or wrongly typed AI fields decode safely and keep metadata as the legacy signal', () {
    for (final Object? flag in <Object?>[null, 'true', 1, <String>[]]) {
      final Map<String, dynamic> json = <String, dynamic>{
        'aiMetadata': <String, Object?>{'prompt': 'a lake'},
        'aiModel': 42,
        if (flag != null) 'isAiGenerated': flag,
      };

      final WallDocDto dto = WallDocDto.fromJson(json);
      expect(dto.isAiGenerated, isFalse);
      expect(dto.aiModel, isEmpty);
      expect(dto.aiMetadata, <String, Object?>{'prompt': 'a lake'});
    }
  });
}
