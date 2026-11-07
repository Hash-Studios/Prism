import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:flutter_test/flutter_test.dart';

String _upper(String key) => key.toUpperCase();

SectionSuggestion _group(String key, List<String> itemKeys) =>
    SectionSuggestion(key: key, name: key, itemKeys: itemKeys);

void main() {
  group('suggestSections', () {
    test('four walls of one mood make one suggestion with all four keys in input order', () {
      final List<SectionSuggestion> result = suggestSections(
        kind: SuggestionKind.mood,
        itemKeys: <String>['w1', 'w2', 'w3', 'w4'],
        traits: <String, WallTraits>{
          for (final String key in <String>['w1', 'w2', 'w3', 'w4'])
            key: const WallTraits(moods: <WallMood>[WallMood.darkQuiet]),
        },
        sections: const <FolderSection>[],
        nameOf: _upper,
      );

      expect(result.length, 1);
      expect(result.single.key, 'dark_quiet');
      expect(result.single.name, 'DARK_QUIET');
      expect(result.single.itemKeys, <String>['w1', 'w2', 'w3', 'w4']);
      expect(result.single.existingSectionId, isNull);
    });

    test('mixed moods: the larger group comes first and a single wall is left out', () {
      final List<SectionSuggestion> result = suggestSections(
        kind: SuggestionKind.mood,
        itemKeys: <String>['w1', 'w2', 'w3', 'w4', 'w5', 'w6'],
        traits: <String, WallTraits>{
          'w1': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          'w2': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          'w3': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          'w4': const WallTraits(moods: <WallMood>[WallMood.minimal]),
          'w5': const WallTraits(moods: <WallMood>[WallMood.minimal]),
          'w6': const WallTraits(moods: <WallMood>[WallMood.brightBold]),
        },
        sections: const <FolderSection>[],
        nameOf: _upper,
      );

      expect(result.map((SectionSuggestion s) => s.key).toList(), <String>['dreamy', 'minimal']);
      expect(result[0].itemKeys, <String>['w1', 'w2', 'w3']);
      expect(result[1].itemKeys, <String>['w4', 'w5']);
    });

    test('walls with no mood, empty traits or no traits entry make no suggestion', () {
      final List<SectionSuggestion> result = suggestSections(
        kind: SuggestionKind.mood,
        itemKeys: <String>['w1', 'w2', 'w3'],
        traits: <String, WallTraits>{'w1': const WallTraits()},
        sections: const <FolderSection>[],
        nameOf: _upper,
      );

      expect(result, isEmpty);
    });

    test('category: General in any case and an empty category are not groups, Abstract x2 is', () {
      final List<SectionSuggestion> result = suggestSections(
        kind: SuggestionKind.category,
        itemKeys: <String>['w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w7'],
        traits: <String, WallTraits>{
          'w1': const WallTraits(category: 'General'),
          'w2': const WallTraits(category: 'GENERAL'),
          'w3': const WallTraits(category: 'general'),
          'w4': const WallTraits(),
          'w5': const WallTraits(category: 'Abstract'),
          'w6': const WallTraits(category: 'Abstract'),
          'w7': const WallTraits(),
        },
        sections: const <FolderSection>[],
        nameOf: _upper,
      );

      expect(result.length, 1);
      expect(result.single.key, 'Abstract');
      expect(result.single.itemKeys, <String>['w5', 'w6']);
    });

    test('colour groups by the first colour only', () {
      final List<SectionSuggestion> result = suggestSections(
        kind: SuggestionKind.colour,
        itemKeys: <String>['w1', 'w2', 'w3', 'w4'],
        traits: <String, WallTraits>{
          'w1': const WallTraits(colours: <String>['red', 'blue']),
          'w2': const WallTraits(colours: <String>['red', 'green']),
          'w3': const WallTraits(colours: <String>['blue', 'red']),
          'w4': const WallTraits(colours: <String>['green']),
        },
        sections: const <FolderSection>[],
        nameOf: _upper,
      );

      expect(result.length, 1);
      expect(result.single.key, 'red');
      expect(result.single.itemKeys, <String>['w1', 'w2']);
    });

    test('a section with the same name, in any case, is joined and does not use a slot', () {
      final List<SectionSuggestion> result = suggestSections(
        kind: SuggestionKind.mood,
        itemKeys: <String>['w1', 'w2'],
        traits: <String, WallTraits>{
          'w1': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          'w2': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
        },
        sections: const <FolderSection>[FolderSection(id: 'mine', name: 'dreamy')],
        nameOf: _upper,
      );

      expect(result.length, 1);
      expect(result.single.name, 'DREAMY');
      expect(result.single.existingSectionId, 'mine');
    });

    test('with 19 sections only one new suggestion is kept, and groups matching existing names are kept', () {
      final List<FolderSection> sections = <FolderSection>[
        for (int i = 1; i <= 18; i++) FolderSection(id: 's$i', name: 'Section $i'),
        const FolderSection(id: 'min', name: 'minimal'),
      ];

      final List<SectionSuggestion> result = suggestSections(
        kind: SuggestionKind.mood,
        itemKeys: <String>['w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w7'],
        traits: <String, WallTraits>{
          'w1': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          'w2': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          'w3': const WallTraits(moods: <WallMood>[WallMood.dreamy]),
          'w4': const WallTraits(moods: <WallMood>[WallMood.minimal]),
          'w5': const WallTraits(moods: <WallMood>[WallMood.minimal]),
          'w6': const WallTraits(moods: <WallMood>[WallMood.brightBold]),
          'w7': const WallTraits(moods: <WallMood>[WallMood.brightBold]),
        },
        sections: sections,
        nameOf: _upper,
      );

      expect(result.map((SectionSuggestion s) => s.key).toList(), <String>['dreamy', 'minimal']);
      expect(result[0].existingSectionId, isNull);
      expect(result[1].existingSectionId, 'min');
    });
  });

  group('bestSuggestionKind', () {
    test('picks the kind with the most grouped walls', () {
      expect(
        bestSuggestionKind(<SuggestionKind, List<SectionSuggestion>>{
          SuggestionKind.mood: <SectionSuggestion>[
            _group('dreamy', <String>['a', 'b', 'c']),
          ],
          SuggestionKind.category: <SectionSuggestion>[
            _group('Abstract', <String>['d', 'e']),
          ],
          SuggestionKind.colour: <SectionSuggestion>[
            _group('red', <String>['f', 'g']),
          ],
        }),
        SuggestionKind.mood,
      );
      expect(
        bestSuggestionKind(<SuggestionKind, List<SectionSuggestion>>{
          SuggestionKind.mood: <SectionSuggestion>[
            _group('dreamy', <String>['a', 'b']),
          ],
          SuggestionKind.category: <SectionSuggestion>[
            _group('Abstract', <String>['c', 'd']),
          ],
          SuggestionKind.colour: <SectionSuggestion>[
            _group('red', <String>['e', 'f', 'g']),
          ],
        }),
        SuggestionKind.colour,
      );
    });

    test('a tie goes to mood, then category', () {
      expect(
        bestSuggestionKind(<SuggestionKind, List<SectionSuggestion>>{
          SuggestionKind.mood: <SectionSuggestion>[
            _group('dreamy', <String>['a', 'b']),
          ],
          SuggestionKind.category: <SectionSuggestion>[
            _group('Abstract', <String>['c', 'd']),
          ],
          SuggestionKind.colour: <SectionSuggestion>[
            _group('red', <String>['e', 'f']),
          ],
        }),
        SuggestionKind.mood,
      );
      expect(
        bestSuggestionKind(<SuggestionKind, List<SectionSuggestion>>{
          SuggestionKind.category: <SectionSuggestion>[
            _group('Abstract', <String>['c', 'd']),
          ],
          SuggestionKind.colour: <SectionSuggestion>[
            _group('red', <String>['e', 'f']),
          ],
        }),
        SuggestionKind.category,
      );
    });
  });
}
