import 'package:Prism/features/wrapped/domain/wrapped.dart';

/// A server doc with 6 showable cards: intro, saves, colours, creator, streak, summary. The `ai` card has value 0 and
/// the `mystery` id is unknown, so both are dropped by the parser.
Map<String, dynamic> fixtureWrappedDoc() => <String, dynamic>{
  'year': 2026,
  'version': 1,
  'through': DateTime.utc(2026, 12, 31),
  'accents': <String>['blue', 'purple', 'teal'],
  'cards': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'intro',
      'hero': <String, dynamic>{'url': 'https://cdn.example.test/wrapped/intro.jpg'},
    },
    <String, dynamic>{
      'id': 'saves',
      'hero': <String, dynamic>{'url': 'https://cdn.example.test/wrapped/saves.jpg'},
      'value': 12,
    },
    <String, dynamic>{
      'id': 'colours',
      'colours': <String>['blue', 'purple', 'teal'],
      'value': 6,
    },
    <String, dynamic>{
      'id': 'ai',
      'hero': <String, dynamic>{'url': 'https://cdn.example.test/wrapped/ai.jpg'},
      'value': 0,
    },
    <String, dynamic>{
      'id': 'creator',
      'creator': <String, dynamic>{'username': 'maya', 'name': 'Maya'},
      'value': 4,
    },
    <String, dynamic>{'id': 'streak', 'value': 5, 'since': '2026-03-02'},
    <String, dynamic>{'id': 'mystery', 'value': 3},
    <String, dynamic>{
      'id': 'summary',
      'thumbs': <String>[
        'https://cdn.example.test/wrapped/thumb-1.jpg',
        'https://cdn.example.test/wrapped/thumb-2.jpg',
        'https://cdn.example.test/wrapped/thumb-3.jpg',
        'https://cdn.example.test/wrapped/thumb-4.jpg',
      ],
    },
  ],
};

/// The parsed fixture year. Fails the test if the fixture stops parsing.
WrappedYear fixtureWrappedYear() => parseWrappedYear(fixtureWrappedDoc())!;
