import 'dart:convert';

import 'package:Prism/core/firestore/dtos/wall_doc_dto.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/public_profile/domain/public_profile_snapshot_codec.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _record(Object? documentIdsJson) => <String, Object?>{
  'itemsJson': jsonEncode(<Map<String, Object?>>[
    <String, Object?>{'id': 'WALLA', 'wallpaper_url': 'https://example.test/a.jpg'},
    <String, Object?>{'id': 'doc-b', 'wallpaper_url': 'https://example.test/b.jpg'},
  ]),
  'documentIdsJson': documentIdsJson,
  'hasMore': false,
};

List<(String, String?)> _decoded(Object? documentIdsJson) => PublicProfileSnapshotCodec.decodeWalls(
  _record(documentIdsJson),
).map((wall) => (wall.doc.id, wall.documentId)).toList();

void main() {
  test('valid document id metadata restores next to each wall', () {
    expect(_decoded('["doc-a","doc-b"]'), <(String, String?)>[('WALLA', 'doc-a'), ('doc-b', 'doc-b')]);
  });

  final Map<String, Object?> unreadableMetadata = <String, Object?>{
    'absent': null,
    'not a string': 7,
    'invalid JSON': '{',
    'a JSON object': '{}',
    'a JSON string': '"doc-a"',
    'a shorter list': '["doc-a"]',
    'a longer list': '["doc-a","doc-b","doc-c"]',
  };
  for (final MapEntry<String, Object?> metadata in unreadableMetadata.entries) {
    test('walls restore with unknown document ids when the metadata is ${metadata.key}', () {
      expect(_decoded(metadata.value), <(String, String?)>[('WALLA', null), ('doc-b', null)]);
    });
  }

  test('only the document ids that are not non-empty strings become unknown', () {
    expect(_decoded('[7,"doc-b"]'), <(String, String?)>[('WALLA', null), ('doc-b', 'doc-b')]);
    expect(_decoded('["",{"id":"doc-b"}]'), <(String, String?)>[('WALLA', null), ('doc-b', null)]);
  });

  bool aiAfterRoundTrip(Map<String, dynamic> wall) {
    final dto = WallDocDto.fromJson(<String, dynamic>{
      'id': 'w',
      'wallpaper_url': 'https://example.test/w.jpg',
      ...wall,
    });
    final record = PublicProfileSnapshotCodec.encodeWalls(<PublicProfileSnapshotWall>[
      (doc: dto, documentId: 'w'),
    ], hasMore: false);
    final restored = PublicProfileSnapshotCodec.decodeWalls(record).single;
    final entity = PublicProfileSnapshotCodec.wallFromDto(restored.doc, 'w');
    final item = entity.toFeedItem() as PrismFeedItem;
    return AiContentFilter.isAi(item.wallpaper);
  }

  test('a wall with the AI flag is AI, also after the snapshot round trip', () {
    expect(aiAfterRoundTrip(<String, dynamic>{'isAiGenerated': true, 'aiModel': 'z-image'}), isTrue);
  });

  test('a wall with only AI metadata is AI', () {
    expect(
      aiAfterRoundTrip(<String, dynamic>{
        'aiMetadata': <String, dynamic>{'prompt': 'a fox'},
      }),
      isTrue,
    );
  });

  test('AI metadata and model survive the snapshot round trip', () {
    final WallDocDto source = WallDocDto.fromJson(<String, dynamic>{
      'id': 'w',
      'wallpaper_url': 'https://example.test/w.jpg',
      'isAiGenerated': true,
      'aiModel': 'Seedream 5 Lite',
      'aiMetadata': <String, Object?>{'prompt': 'a fox'},
    });
    final Map<String, Object?> record = PublicProfileSnapshotCodec.encodeWalls(<PublicProfileSnapshotWall>[
      (doc: source, documentId: 'wall-doc'),
    ], hasMore: false);

    final WallDocDto restored = PublicProfileSnapshotCodec.decodeWalls(record).single.doc;

    expect(restored.isAiGenerated, isTrue);
    expect(restored.aiModel, 'Seedream 5 Lite');
    expect(restored.aiMetadata, <String, Object?>{'prompt': 'a fox'});
  });

  test('a plain wall is not AI', () {
    expect(aiAfterRoundTrip(<String, dynamic>{}), isFalse);
  });
}
