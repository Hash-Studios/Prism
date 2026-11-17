import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/data/personalized_ranking_service.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 11, 18);

FeedItemEntity _wall(String id, List<String> tags, {String creator = 'someone@x.com', String? group}) =>
    FeedItemEntity.prism(
      id: id,
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.prism,
          fullUrl: 'https://n.test/$id.jpg',
          thumbnailUrl: 'https://n.test/$id-t.jpg',
          authorEmail: creator,
        ),
        tags: tags,
        variantGroupId: group,
      ),
    );

List<String> _rank(
  FeedItemEntity current,
  List<FeedItemEntity> items, {
  TasteProfile? profile,
  Set<String> hidden = const <String>{},
  Set<String> usedGroups = const <String>{},
}) => rankNextWalls(
  current: current,
  items: items,
  profile: profile ?? TasteProfile.empty,
  hiddenKeys: hidden,
  usedGroups: usedGroups,
).map((item) => item.id).toList();

void main() {
  final FeedItemEntity open = _wall('open', const <String>['forest', 'fog']);

  test('walls that share more with the open wall come first', () {
    expect(
      _rank(open, <FeedItemEntity>[
        _wall('none', const <String>['city']),
        _wall('both', const <String>['forest', 'fog']),
        _wall('one', const <String>['forest']),
      ]),
      <String>['both', 'one', 'none'],
    );
  });

  test('the same creator counts as related', () {
    expect(
      _rank(_wall('open', const <String>['forest', 'fog'], creator: 'a@x.com'), <FeedItemEntity>[
        _wall('other', const <String>['forest']),
        _wall('same', const <String>['forest'], creator: 'a@x.com'),
      ]),
      <String>['same', 'other'],
    );
  });

  test('taste breaks a tie and a liked wall can pass a slightly more related one', () {
    final TasteProfile profile = TasteProfile.build(
      interests: const <String>['snow'],
      following: const <String>[],
      signals: const <TasteSignal>[],
      now: _now,
    );
    expect(
      _rank(open, <FeedItemEntity>[
        _wall('plain', const <String>['forest']),
        _wall('snowy', const <String>['forest', 'snow']),
        _wall('closest', const <String>['forest', 'fog']),
      ], profile: profile),
      <String>['snowy', 'closest', 'plain'],
    );
  });

  test('a disliked creator sinks below an equally related wall', () {
    final TasteProfile profile = TasteProfile.build(
      interests: const <String>[],
      following: const <String>[],
      signals: <TasteSignal>[
        TasteSignal(action: TasteAction.lessLikeThis, at: _now, terms: const <String>['x'], creator: 'bad@x.com'),
      ],
      now: _now,
    );
    expect(
      _rank(open, <FeedItemEntity>[
        _wall('bad', const <String>['forest', 'fog'], creator: 'bad@x.com'),
        _wall('good', const <String>['forest', 'fog']),
      ], profile: profile),
      <String>['good', 'bad'],
    );
  });

  test('hidden walls drop out', () {
    expect(
      _rank(
        open,
        <FeedItemEntity>[
          _wall('a', const <String>['forest']),
          _wall('b', const <String>['forest']),
        ],
        hidden: <String>{'https://n.test/a.jpg'},
      ),
      <String>['b'],
    );
  });

  test('a light/dark pair keeps its better wall, and the open wall partner and used groups drop out', () {
    expect(
      _rank(
        _wall('open', const <String>['forest'], group: 'own'),
        <FeedItemEntity>[
          _wall('partner', const <String>['forest'], group: 'own'),
          _wall('dark', const <String>['city'], group: 'g1'),
          _wall('light', const <String>['forest'], group: 'g1'),
          _wall('seen', const <String>['forest'], group: 'g2'),
          _wall('solo', const <String>['city']),
        ],
        usedGroups: <String>{'g2'},
      ),
      <String>['light', 'solo'],
    );
  });

  test('equal scores keep the query order', () {
    expect(
      _rank(open, <FeedItemEntity>[
        _wall('c', const <String>['city']),
        _wall('a', const <String>['sea']),
        _wall('b', const <String>['sky']),
      ]),
      <String>['c', 'a', 'b'],
    );
  });
}
