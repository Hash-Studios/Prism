import 'dart:convert';

import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/data/feed_item_cache_codec.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/prism_feed/data/dtos/prism_wall_doc_dto.dart';
import 'package:Prism/features/prism_feed/data/mappers/prism_wall_doc_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

const String _poster = 'https://img.example.com/previews/poster.img';
const String _video = 'https://img.example.com/previews/video.img';

Map<String, dynamic> _doc([Map<String, dynamic> extra = const <String, dynamic>{}]) => <String, dynamic>{
  'id': 'LIVE000001',
  'wallpaper_url': '',
  'wallpaper_thumb': _poster,
  'review': true,
  ...extra,
};

PrismWallpaper _map(Map<String, dynamic> data) => PrismWallDocDto.fromJson(data).toDomain(docId: 'doc1');

void main() {
  test('an old wall document without kind is a still wall', () {
    final PrismWallpaper wall = _map(_doc());
    expect(wall.kind, WallKind.still);
    expect(wall.live, isNull);
    expect(wall.thumbnailUrl, _poster);
  });

  test('a verified live wall keeps its poster as the image and its video facts', () {
    final PrismWallpaper wall = _map(
      _doc(<String, dynamic>{
        'kind': 'live',
        'live': <String, dynamic>{
          'video': _video,
          'durationMs': 4200,
          'width': 1080,
          'height': 1920,
          'loop': true,
          'verified': true,
        },
      }),
    );
    expect(wall.kind, WallKind.live);
    expect(wall.thumbnailUrl, _poster);
    expect(wall.live, const WallLive(videoUrl: _video, durationMs: 4200, width: 1080, height: 1920, verified: true));
  });

  test('a live wall with a broken video shows as its poster', () {
    for (final Object? live in <Object?>[
      null,
      'not a map',
      <String, dynamic>{'video': 'http://img.example.com/v.img'},
      <String, dynamic>{'video': 'file:///v.mp4'},
      <String, dynamic>{},
    ]) {
      expect(_map(_doc(<String, dynamic>{'kind': 'live', 'live': ?live})).kind, WallKind.still, reason: '$live');
    }
  });

  test('nonfinite video facts do not stop a live wall from loading', () {
    final wall = _map(
      _doc(<String, dynamic>{
        'kind': 'live',
        'live': <String, dynamic>{
          'video': _video,
          'durationMs': double.infinity,
          'width': double.nan,
          'height': double.negativeInfinity,
        },
      }),
    );
    expect(wall.live?.videoUrl, _video);
    expect(wall.live?.durationMs, isNull);
    expect(wall.live?.width, isNull);
    expect(wall.live?.height, isNull);
    expect(wall.thumbnailUrl, _poster);
  });

  test('an unknown kind is a still wall', () {
    expect(
      _map(
        _doc(<String, dynamic>{
          'kind': 'gif',
          'live': <String, dynamic>{'video': _video},
        }),
      ).kind,
      WallKind.still,
    );
  });

  test('the feed cache keeps the live video', () {
    final PrismFeedItem item = PrismFeedItem(
      id: 'LIVE000001',
      wallpaper: _map(
        _doc(<String, dynamic>{
          'kind': 'live',
          'live': <String, dynamic>{'video': _video, 'durationMs': 3000, 'verified': true},
        }),
      ),
    );
    final Map<String, dynamic> json = jsonDecode(jsonEncode(encodeFeedItem(item))) as Map<String, dynamic>;
    final PrismFeedItem? decoded = decodeFeedItem(json) as PrismFeedItem?;
    expect(decoded?.wallpaper.live, item.wallpaper.live);
    expect(decoded?.wallpaper.kind, WallKind.live);
  });
}
