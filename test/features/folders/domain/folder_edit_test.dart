import 'package:Prism/features/folders/domain/entities/folder_edit.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:flutter_test/flutter_test.dart';

const FolderSection _dark = FolderSection(id: 'dark', name: 'Dark');
const FolderSection _bright = FolderSection(id: 'bright', name: 'Bright');

/// Twenty sections, the most a folder can have.
List<FolderSection> _twenty() => <FolderSection>[
  for (int i = 1; i <= 20; i++) FolderSection(id: 's$i', name: 'Section $i'),
];

void main() {
  group('applyFolderEdit: SectionAdded', () {
    test('appends the new section', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark],
        const <String, String?>{},
        const SectionAdded(id: 'bright', name: ' Bright '),
      );

      expect(result!.sections, <FolderSection>[_dark, _bright]);
      expect(result.moves, isEmpty);
    });

    test('rejects a bad name', () {
      const Map<String, String?> none = <String, String?>{};

      expect(applyFolderEdit(<FolderSection>[_dark], none, const SectionAdded(id: 'bright', name: '')), isNull);
      expect(applyFolderEdit(<FolderSection>[_dark], none, SectionAdded(id: 'bright', name: 'a' * 41)), isNull);
    });

    test('rejects a bad id', () {
      const Map<String, String?> none = <String, String?>{};

      expect(applyFolderEdit(<FolderSection>[_dark], none, const SectionAdded(id: 'has space', name: 'X')), isNull);
      expect(
        applyFolderEdit(
          <FolderSection>[_dark],
          none,
          const SectionAdded(id: 'abcdefghijklmnopqrstuvwxyz0123456', name: 'X'),
        ),
        isNull,
      );
    });

    test('rejects a duplicate id', () {
      expect(
        applyFolderEdit(
          <FolderSection>[_dark],
          const <String, String?>{},
          const SectionAdded(id: 'dark', name: 'Night'),
        ),
        isNull,
      );
    });

    test('rejects a 21st section', () {
      expect(
        applyFolderEdit(_twenty(), const <String, String?>{}, const SectionAdded(id: 'extra', name: 'Extra')),
        isNull,
      );
    });
  });

  group('applyFolderEdit: SectionRenamed', () {
    test('changes only that section', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        const <String, String?>{},
        const SectionRenamed(id: 'bright', name: 'Light'),
      );

      expect(result!.sections, <FolderSection>[_dark, const FolderSection(id: 'bright', name: 'Light')]);
      expect(result.moves, isEmpty);
    });

    test('the same name after trimming leaves the sections unchanged', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        const <String, String?>{},
        const SectionRenamed(id: 'dark', name: ' Dark '),
      );

      expect(result!.sections, isNull);
      expect(result.moves, isEmpty);
    });

    test('an unknown id is rejected', () {
      expect(
        applyFolderEdit(
          <FolderSection>[_dark],
          const <String, String?>{},
          const SectionRenamed(id: 'nope', name: 'Night'),
        ),
        isNull,
      );
    });
  });

  group('applyFolderEdit: SectionDeleted', () {
    test('removes the section and writes no moves', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        const <String, String?>{'prism_w1': 'dark'},
        const SectionDeleted('dark'),
      );

      expect(result!.sections, <FolderSection>[_bright]);
      expect(result.moves, isEmpty);
    });

    test('a wall of the deleted section keeps its old id and reads as Unsorted', () {
      final FolderEditResult? deleted = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        const <String, String?>{'prism_w1': 'dark'},
        const SectionDeleted('dark'),
      );
      final FolderEditResult? unsorted = applyFolderEdit(deleted!.sections!, const <String, String?>{
        'prism_w1': 'dark',
      }, const WallsMoved(itemKeys: <String>['prism_w1'], sectionId: null, method: WallMoveMethod.menu));

      expect(unsorted, isNotNull);
      expect(unsorted!.moves, isEmpty);
    });

    test('an unknown id is rejected', () {
      expect(applyFolderEdit(<FolderSection>[_dark], const <String, String?>{}, const SectionDeleted('nope')), isNull);
    });
  });

  group('applyFolderEdit: SectionMoved', () {
    const List<FolderSection> abcd = <FolderSection>[
      FolderSection(id: 'a', name: 'A'),
      FolderSection(id: 'b', name: 'B'),
      FolderSection(id: 'c', name: 'C'),
      FolderSection(id: 'd', name: 'D'),
    ];

    List<String> ids(FolderEditResult? result) => result!.sections!.map((FolderSection s) => s.id).toList();

    test('reorders the sections', () {
      expect(ids(applyFolderEdit(abcd, const <String, String?>{}, const SectionMoved(id: 'a', toIndex: 3))), <String>[
        'b',
        'c',
        'd',
        'a',
      ]);
      expect(ids(applyFolderEdit(abcd, const <String, String?>{}, const SectionMoved(id: 'd', toIndex: 1))), <String>[
        'a',
        'd',
        'b',
        'c',
      ]);
    });

    test('toIndex clamps to the ends of the list', () {
      expect(ids(applyFolderEdit(abcd, const <String, String?>{}, const SectionMoved(id: 'a', toIndex: 99))), <String>[
        'b',
        'c',
        'd',
        'a',
      ]);
      expect(ids(applyFolderEdit(abcd, const <String, String?>{}, const SectionMoved(id: 'c', toIndex: -5))), <String>[
        'c',
        'a',
        'b',
        'd',
      ]);
    });

    test('the same index leaves the sections unchanged', () {
      final FolderEditResult? result = applyFolderEdit(
        abcd,
        const <String, String?>{},
        const SectionMoved(id: 'b', toIndex: 1),
      );

      expect(result!.sections, isNull);
      expect(result.moves, isEmpty);
    });
  });

  group('applyFolderEdit: WallsMoved', () {
    const Map<String, String?> sectionOf = <String, String?>{
      'prism_w1': 'dark',
      'prism_w2': null,
      'prism_w3': 'gone',
      'prism_w4': 'bright',
    };

    test('moves walls to a section', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        sectionOf,
        const WallsMoved(itemKeys: <String>['prism_w2', 'prism_w4'], sectionId: 'dark', method: WallMoveMethod.drag),
      );

      expect(result!.sections, isNull);
      expect(result.moves, <String, String?>{'prism_w2': 'dark', 'prism_w4': 'dark'});
    });

    test('moves walls to Unsorted with a null section id', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        sectionOf,
        const WallsMoved(itemKeys: <String>['prism_w1'], sectionId: null, method: WallMoveMethod.menu),
      );

      expect(result!.moves, <String, String?>{'prism_w1': null});
    });

    test('skips walls already in the target section', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        sectionOf,
        const WallsMoved(itemKeys: <String>['prism_w1', 'prism_w2'], sectionId: 'dark', method: WallMoveMethod.drag),
      );

      expect(result!.moves, <String, String?>{'prism_w2': 'dark'});
    });

    test('a wall whose section was deleted counts as Unsorted', () {
      final FolderEditResult? toUnsorted = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        sectionOf,
        const WallsMoved(itemKeys: <String>['prism_w3'], sectionId: null, method: WallMoveMethod.menu),
      );
      final FolderEditResult? toDark = applyFolderEdit(
        <FolderSection>[_dark, _bright],
        sectionOf,
        const WallsMoved(itemKeys: <String>['prism_w3'], sectionId: 'dark', method: WallMoveMethod.drag),
      );

      expect(toUnsorted!.moves, isEmpty);
      expect(toDark!.moves, <String, String?>{'prism_w3': 'dark'});
    });

    test('an unknown section is rejected', () {
      expect(
        applyFolderEdit(
          <FolderSection>[_dark],
          sectionOf,
          const WallsMoved(itemKeys: <String>['prism_w1'], sectionId: 'nope', method: WallMoveMethod.drag),
        ),
        isNull,
      );
    });

    test('an unknown item key is rejected', () {
      expect(
        applyFolderEdit(
          <FolderSection>[_dark],
          sectionOf,
          const WallsMoved(itemKeys: <String>['prism_zz'], sectionId: 'dark', method: WallMoveMethod.drag),
        ),
        isNull,
      );
    });

    test('empty item keys are rejected', () {
      expect(
        applyFolderEdit(
          <FolderSection>[_dark],
          sectionOf,
          const WallsMoved(itemKeys: <String>[], sectionId: 'dark', method: WallMoveMethod.drag),
        ),
        isNull,
      );
    });
  });

  group('applyFolderEdit: SuggestionsAccepted', () {
    const Map<String, String?> sectionOf = <String, String?>{'prism_w1': null, 'prism_w2': null};

    test('a new group adds a section and moves its walls', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark],
        sectionOf,
        const SuggestionsAccepted(<AcceptedGroup>[
          AcceptedGroup(sectionId: 'bright', name: 'Bright', itemKeys: <String>['prism_w1', 'prism_w2']),
        ]),
      );

      expect(result!.sections, <FolderSection>[_dark, _bright]);
      expect(result.moves, <String, String?>{'prism_w1': 'bright', 'prism_w2': 'bright'});
    });

    test('a group whose section already exists adds no section', () {
      final FolderEditResult? result = applyFolderEdit(
        <FolderSection>[_dark],
        sectionOf,
        const SuggestionsAccepted(<AcceptedGroup>[
          AcceptedGroup(sectionId: 'dark', name: 'Dark', itemKeys: <String>['prism_w1']),
        ]),
      );

      expect(result!.sections, isNull);
      expect(result.moves, <String, String?>{'prism_w1': 'dark'});
    });

    test('more than 20 sections in total is rejected', () {
      expect(
        applyFolderEdit(
          _twenty(),
          sectionOf,
          const SuggestionsAccepted(<AcceptedGroup>[
            AcceptedGroup(sectionId: 'bright', name: 'Bright', itemKeys: <String>['prism_w1']),
          ]),
        ),
        isNull,
      );
    });
  });
}
