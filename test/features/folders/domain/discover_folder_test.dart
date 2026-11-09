import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:flutter_test/flutter_test.dart';

DiscoverFolder _folder(
  String id, {
  String owner = 'owner',
  List<String> moods = const <String>[],
  List<String> categories = const <String>[],
}) => DiscoverFolder(id: id, ownerId: owner, name: 'Folder $id', itemCount: 10, moods: moods, categories: categories);

List<String> _ids(Iterable<DiscoverFolder> folders) => folders.map((f) => f.id).toList();

void main() {
  group('rankLikeYourSaves', () {
    test('ranks by shared moods and categories, weighted by how recent each save is', () {
      final DiscoverFolder a = _folder(
        'A',
        owner: 'a',
        moods: const <String>['dreamy'],
        categories: const <String>['Nature'],
      );
      final DiscoverFolder b = _folder('B', owner: 'b', moods: const <String>['dark_quiet']);
      final DiscoverFolder c = _folder('C', owner: 'c', categories: const <String>['Abstract']);
      final DiscoverFolder d = _folder('D', owner: 'd');

      final List<DiscoverFolder> ranked = rankLikeYourSaves(
        <DiscoverFolder>[a, b, c, d],
        const <WallTraits>[
          WallTraits(moods: <WallMood>[WallMood.dreamy], category: 'Nature'),
          WallTraits(category: 'Abstract'),
          WallTraits(moods: <WallMood>[WallMood.dreamy]),
        ],
      );

      expect(_ids(ranked), <String>['A', 'C']);
    });

    test('the General category in saves gives no score', () {
      final DiscoverFolder general = _folder('G', owner: 'g', categories: const <String>['General']);
      final DiscoverFolder dreamy = _folder('A', owner: 'a', moods: const <String>['dreamy']);

      final List<DiscoverFolder> ranked = rankLikeYourSaves(
        <DiscoverFolder>[general, dreamy],
        const <WallTraits>[
          WallTraits(moods: <WallMood>[WallMood.dreamy], category: 'General'),
        ],
      );

      expect(_ids(ranked), <String>['A']);
      expect(
        rankLikeYourSaves(<DiscoverFolder>[general], const <WallTraits>[WallTraits(category: 'General')]),
        isEmpty,
      );
    });

    test('an owner shows at most two folders', () {
      final List<DiscoverFolder> folders = <DiscoverFolder>[
        _folder('f1', owner: 'same', moods: const <String>['dreamy']),
        _folder('f2', owner: 'same', moods: const <String>['dreamy']),
        _folder('f3', owner: 'same', moods: const <String>['dreamy']),
      ];

      final List<DiscoverFolder> ranked = rankLikeYourSaves(folders, const <WallTraits>[
        WallTraits(moods: <WallMood>[WallMood.dreamy]),
      ]);

      expect(_ids(ranked), <String>['f1', 'f2']);
    });

    test('ties keep the candidate order', () {
      final List<DiscoverFolder> folders = <DiscoverFolder>[
        _folder('T1', owner: 'x', moods: const <String>['dreamy']),
        _folder('T2', owner: 'y', moods: const <String>['dreamy']),
        _folder('T3', owner: 'z', moods: const <String>['dreamy']),
      ];

      final List<DiscoverFolder> ranked = rankLikeYourSaves(folders, const <WallTraits>[
        WallTraits(moods: <WallMood>[WallMood.dreamy]),
      ]);

      expect(_ids(ranked), <String>['T1', 'T2', 'T3']);
    });

    test('no saves gives an empty list', () {
      final List<DiscoverFolder> folders = <DiscoverFolder>[
        _folder('A', moods: const <String>['dreamy'], categories: const <String>['Nature']),
      ];

      expect(rankLikeYourSaves(folders, const <WallTraits>[]), isEmpty);
    });
  });

  group('FolderDiscoverLists.visibleTo', () {
    final FolderDiscoverLists lists = FolderDiscoverLists(
      trending: <DiscoverFolder>[
        _folder('t_me', owner: 'me'),
        _folder('t_blocked', owner: 'blocked'),
        _folder('t_ok', owner: 'ok'),
      ],
      fresh: <DiscoverFolder>[
        _folder('f_me', owner: 'me'),
        _folder('f_blocked', owner: 'blocked'),
        _folder('f_ok', owner: 'ok'),
      ],
    );

    test('removes the viewer and blocked creators from both lists', () {
      final FolderDiscoverLists visible = lists.visibleTo('me', KnownBlockedCreators(<String>{'blocked'}));

      expect(_ids(visible.trending), <String>['t_ok']);
      expect(_ids(visible.fresh), <String>['f_ok']);
    });

    test('an unknown block list hides every creator that has a uid', () {
      final FolderDiscoverLists visible = FolderDiscoverLists(
        trending: <DiscoverFolder>[
          _folder('t_ok', owner: 'ok'),
          _folder('t_anon', owner: ''),
        ],
      ).visibleTo('me', const UnknownBlockedCreators());

      expect(_ids(visible.trending), <String>['t_anon']);
      expect(visible.fresh, isEmpty);
    });
  });

  group('FolderDiscoverLists.candidates', () {
    test('a folder in both lists appears once, in trending order', () {
      final DiscoverFolder trendingY = _folder('y', owner: 'trend');
      final FolderDiscoverLists lists = FolderDiscoverLists(
        trending: <DiscoverFolder>[
          _folder('x', owner: 'x'),
          trendingY,
        ],
        fresh: <DiscoverFolder>[
          _folder('y', owner: 'fresh'),
          _folder('z', owner: 'z'),
        ],
      );

      final List<DiscoverFolder> candidates = lists.candidates;

      expect(_ids(candidates), <String>['x', 'y', 'z']);
      expect(identical(candidates[1], trendingY), isTrue);
    });
  });
}
