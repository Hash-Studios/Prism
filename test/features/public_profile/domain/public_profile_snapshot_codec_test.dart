import 'dart:convert';

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
}
