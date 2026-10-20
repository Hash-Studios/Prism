import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/biz/wall_moderation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FirestoreDocument wall(Object? moderation) =>
      FirestoreDocument('w1', <String, dynamic>{'review': false, 'moderation': ?moderation});

  test('a wall without the field, or with something other than a map, is not checked', () {
    expect(wallModeration(wall(null)), isNull);
    expect(wallModeration(wall('duplicate')), isNull);
    expect(wallModeration(wall(<String>['duplicate'])), isNull);
  });

  test('reads a full result', () {
    final WallModeration? moderation = wallModeration(
      wall(<String, dynamic>{
        'v': 1,
        'flags': <String>['duplicate', 'web_match', 'text', 'logo', 'unsafe'],
        'duplicate': <String, dynamic>{'wallId': 'w9', 'similarity': 0.964, 'thumb': 'https://example.com/w9.jpg'},
        'web': <Map<String, String>>[
          <String, String>{'url': 'https://backdrops.app/a', 'host': 'backdrops.app'},
          <String, String>{'url': 'http://example.org/b', 'host': 'example.org'},
        ],
        'words': <String>['@someone', 'backdrops'],
        'logos': <String>['Nike'],
        'unsafe': <String>['adult'],
      }),
    );

    expect(moderation, isNotNull);
    expect(moderation!.flags, <ModerationFlag>[
      ModerationFlag.unsafe,
      ModerationFlag.duplicate,
      ModerationFlag.webMatch,
      ModerationFlag.logo,
      ModerationFlag.text,
    ]);
    expect(moderation.duplicate!.wallId, 'w9');
    expect(moderation.duplicate!.similarity, 0.964);
    expect(moderation.duplicate!.percent, 96);
    expect(moderation.duplicate!.thumb, 'https://example.com/w9.jpg');
    expect(moderation.web.map((ModerationWebMatch m) => (m.url, m.host)), <(String, String)>[
      ('https://backdrops.app/a', 'backdrops.app'),
      ('http://example.org/b', 'example.org'),
    ]);
    expect(moderation.words, <String>['@someone', 'backdrops']);
    expect(moderation.logos, <String>['Nike']);
    expect(moderation.unsafe, <String>['adult']);
  });

  test('an empty map is a clear result', () {
    final WallModeration? moderation = wallModeration(wall(<String, dynamic>{'v': 1, 'flags': <String>[]}));

    expect(moderation!.flags, isEmpty);
    expect(moderation.duplicate, isNull);
    expect(moderation.web, isEmpty);
    expect(moderation.words, isEmpty);
  });

  test('unknown flags are ignored and repeats collapse', () {
    final WallModeration? moderation = wallModeration(
      wall(<String, dynamic>{
        'flags': <Object?>['text', 'hologram', 7, null, 'text', 'duplicate'],
      }),
    );

    expect(moderation!.flags, <ModerationFlag>[ModerationFlag.duplicate, ModerationFlag.text]);
  });

  test('wrong types become empty values', () {
    final WallModeration? moderation = wallModeration(
      wall(<String, dynamic>{
        'flags': 'duplicate',
        'duplicate': <String, dynamic>{'wallId': 5, 'similarity': 'high'},
        'web': 'backdrops.app',
        'words': <Object?>['ok', 3, '', null],
        'logos': 4,
        'unsafe': <String, dynamic>{},
      }),
    );

    expect(moderation!.flags, isEmpty);
    expect(moderation.duplicate, isNull);
    expect(moderation.web, isEmpty);
    expect(moderation.words, <String>['ok']);
    expect(moderation.logos, isEmpty);
    expect(moderation.unsafe, isEmpty);
  });

  test('a duplicate without a thumb keeps an empty thumb, and an int similarity counts', () {
    final WallModeration? moderation = wallModeration(
      wall(<String, dynamic>{
        'flags': <String>['duplicate'],
        'duplicate': <String, dynamic>{'wallId': 'w9', 'similarity': 1},
      }),
    );

    expect(moderation!.duplicate!.thumb, isEmpty);
    expect(moderation.duplicate!.percent, 100);
  });

  test('web matches need a host and an http or https url', () {
    final WallModeration? moderation = wallModeration(
      wall(<String, dynamic>{
        'flags': <String>['web_match'],
        'web': <Object?>[
          <String, String>{'url': 'javascript:alert(1)', 'host': 'evil'},
          <String, String>{'url': 'https://ok.example/a', 'host': ''},
          <String, String>{'url': 'https://ok.example/a'},
          'https://ok.example/a',
          <String, String>{'url': 'https://ok.example/a', 'host': 'ok.example'},
        ],
      }),
    );

    expect(moderation!.web.map((ModerationWebMatch m) => m.host), <String>['ok.example']);
  });
}
