import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// One grapheme of 8 UTF-16 units: man, ZWJ, woman, ZWJ, girl.
const String _family = '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}';

PrismFavouriteWall _wall(String id) => PrismFavouriteWall(
  id: id,
  wallpaper: PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: 'https://x/$id.jpg',
      thumbnailUrl: 'https://x/$id-t.jpg',
    ),
  ),
);

void main() {
  group('normalizeSectionName', () {
    test('trims the name', () {
      expect(normalizeSectionName('  Dark Sky  '), 'Dark Sky');
    });

    test('an empty or blank name is null', () {
      expect(normalizeSectionName(''), isNull);
      expect(normalizeSectionName('   '), isNull);
    });

    test('40 graphemes are allowed and 41 are not', () {
      expect(normalizeSectionName('a' * 40), 'a' * 40);
      expect(normalizeSectionName('a' * 41), isNull);
    });

    test('the UTF-16 cap the rules use stops long emoji names: 20 family emoji (160 units) fit, 21 do not', () {
      expect(normalizeSectionName(_family * 20), _family * 20);
      expect(normalizeSectionName(_family * 21), isNull);
      expect(normalizeSectionName(_family * 40), isNull);
    });
  });

  group('folderSectionsFromDoc', () {
    test('parses a valid entry', () {
      expect(
        folderSectionsFromDoc(<Object?>[
          <String, String>{'id': 'a', 'name': 'Dark'},
        ]),
        <FolderSection>[const FolderSection(id: 'a', name: 'Dark')],
      );
    });

    test('skips malformed entries and keeps the first of a repeated id', () {
      final List<Object?> raw = <Object?>[
        'not a map',
        <String, String>{'id': 'b'},
        <String, String>{'id': 'has space', 'name': 'Spaced'},
        <String, String>{'id': 'abcdefghijklmnopqrstuvwxyz0123456', 'name': 'Too long'},
        <String, String>{'id': 'c', 'name': '   '},
        <String, Object>{'id': 'd', 'name': 5},
        <String, String>{'id': 'e', 'name': 'First'},
        <String, String>{'id': 'e', 'name': 'Second'},
        <String, String>{'id': 'abcdefghijklmnopqrstuvwxyz012345', 'name': 'Max id'},
      ];

      expect(folderSectionsFromDoc(raw), <FolderSection>[
        const FolderSection(id: 'e', name: 'First'),
        const FolderSection(id: 'abcdefghijklmnopqrstuvwxyz012345', name: 'Max id'),
      ]);
    });

    test('keeps at most 20 sections from a list of 25', () {
      final List<Object?> raw = <Object?>[
        for (int i = 1; i <= 25; i++) <String, String>{'id': 's$i', 'name': 'Section $i'},
      ];

      expect(folderSectionsFromDoc(raw).map((FolderSection s) => s.id).toList(), <String>[
        's1',
        's2',
        's3',
        's4',
        's5',
        's6',
        's7',
        's8',
        's9',
        's10',
        's11',
        's12',
        's13',
        's14',
        's15',
        's16',
        's17',
        's18',
        's19',
        's20',
      ]);
    });

    test('a value that is not a list gives no sections', () {
      expect(folderSectionsFromDoc('dark'), isEmpty);
      expect(folderSectionsFromDoc(null), isEmpty);
    });
  });

  group('moveEntry', () {
    const List<String> abcd = <String>['a', 'b', 'c', 'd'];

    test('moves an entry forward', () {
      expect(moveEntry(abcd, 0, 3), <String>['b', 'c', 'd', 'a']);
    });

    test('moves an entry backward', () {
      expect(moveEntry(abcd, 3, 0), <String>['d', 'a', 'b', 'c']);
    });

    test('moves an entry one place down', () {
      expect(moveEntry(abcd, 1, 2), <String>['a', 'c', 'b', 'd']);
    });

    test('the same index leaves the order unchanged', () {
      expect(moveEntry(abcd, 2, 2), <String>['a', 'b', 'c', 'd']);
    });

    test('an index past the end clamps to the last place', () {
      expect(moveEntry(abcd, 0, 99), <String>['b', 'c', 'd', 'a']);
    });

    test('a bad from index returns a copy of the input', () {
      final List<String> low = moveEntry(abcd, -1, 2);
      final List<String> high = moveEntry(abcd, 4, 0);

      expect(low, <String>['a', 'b', 'c', 'd']);
      expect(low, isNot(same(abcd)));
      expect(high, <String>['a', 'b', 'c', 'd']);
      expect(high, isNot(same(abcd)));
    });

    test('an empty list stays empty', () {
      expect(moveEntry(<String>[], 0, 0), isEmpty);
    });
  });

  group('folderGroups', () {
    const List<FolderSection> sections = <FolderSection>[
      FolderSection(id: 'dark', name: 'Dark'),
      FolderSection(id: 'bright', name: 'Bright'),
      FolderSection(id: 'empty', name: 'Empty'),
    ];

    test('Unsorted comes first, then each section in order', () {
      // Newest first. w4 names a section that is gone. w5 has no entry in sectionOf.
      final List<FavouriteWallEntity> walls = <FavouriteWallEntity>[
        _wall('w3'),
        _wall('w1'),
        _wall('w2'),
        _wall('w4'),
        _wall('w5'),
      ];
      final Map<String, String> sectionOf = <String, String>{
        'prism_w1': 'bright',
        'prism_w2': 'dark',
        'prism_w3': 'bright',
        'prism_w4': 'gone',
      };

      final List<FolderGroup> groups = folderGroups(sections, walls, sectionOf);

      expect(groups.map((FolderGroup g) => g.key).toList(), <String>['', 'dark', 'bright', 'empty']);
      expect(
        groups.map((FolderGroup g) => g.walls.map((FavouriteWallEntity w) => w.id).toList()).toList(),
        <List<String>>[
          <String>['w4', 'w5'],
          <String>['w2'],
          <String>['w3', 'w1'],
          <String>[],
        ],
      );
    });

    test('each group keeps the input wall order and its cover is the first wall', () {
      final List<FavouriteWallEntity> walls = <FavouriteWallEntity>[_wall('w3'), _wall('w1')];
      final Map<String, String> sectionOf = <String, String>{'prism_w1': 'bright', 'prism_w3': 'bright'};

      final FolderGroup bright = folderGroups(sections, walls, sectionOf)[1];

      expect(bright.section, const FolderSection(id: 'bright', name: 'Bright'));
      expect(bright.walls.map((FavouriteWallEntity w) => w.id).toList(), <String>['w3', 'w1']);
      expect(bright.cover?.id, 'w3');
    });

    test('an empty section is present with no walls', () {
      final List<FolderGroup> groups = folderGroups(
        sections,
        <FavouriteWallEntity>[_wall('w1')],
        <String, String>{'prism_w1': 'dark'},
      );

      expect(groups.last.key, 'empty');
      expect(groups.last.walls, isEmpty);
      expect(groups.last.cover, isNull);
    });

    test('Unsorted is left out when empty, unless keepEmptyUnsorted is true', () {
      final List<FavouriteWallEntity> walls = <FavouriteWallEntity>[_wall('w1')];
      final Map<String, String> sectionOf = <String, String>{'prism_w1': 'dark'};

      expect(folderGroups(sections, walls, sectionOf).map((FolderGroup g) => g.key).toList(), <String>[
        'dark',
        'bright',
        'empty',
      ]);

      final List<FolderGroup> kept = folderGroups(sections, walls, sectionOf, keepEmptyUnsorted: true);

      expect(kept.map((FolderGroup g) => g.key).toList(), <String>['', 'dark', 'bright', 'empty']);
      expect(kept.first.section, isNull);
      expect(kept.first.walls, isEmpty);
    });
  });
}
