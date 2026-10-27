import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:flutter_test/flutter_test.dart';

const String _mapUrl = 'https://img.prismwalls.com/spatial/v1/w.png';

void main() {
  group('WallSpatial.parse', () {
    test('reads a great tier with an https map', () {
      expect(
        WallSpatial.parse(<String, Object?>{'tier': 'great', 'map': _mapUrl, 'v': 1}),
        const WallSpatial(tier: WallSpatialTier.great, mapUrl: _mapUrl),
      );
    });

    test('reads an ok tier', () {
      expect(WallSpatial.parse(<String, Object?>{'tier': 'ok', 'map': _mapUrl})?.tier, WallSpatialTier.ok);
    });

    test('reads a none tier', () {
      expect(WallSpatial.parse(<String, Object?>{'tier': 'none'}), const WallSpatial(tier: WallSpatialTier.none));
    });

    test('gives null for an unknown tier', () {
      expect(WallSpatial.parse(<String, Object?>{'tier': 'huge', 'map': _mapUrl}), isNull);
    });

    test('gives null for a non-map value', () {
      expect(WallSpatial.parse(null), isNull);
      expect(WallSpatial.parse('great'), isNull);
    });

    test('gives a null map URL for an http map', () {
      expect(
        WallSpatial.parse(<String, Object?>{'tier': 'great', 'map': 'http://img.prismwalls.com/w.png'}),
        const WallSpatial(tier: WallSpatialTier.great),
      );
    });

    test('gives a null map URL when the map is missing', () {
      expect(WallSpatial.parse(<String, Object?>{'tier': 'ok'}), const WallSpatial(tier: WallSpatialTier.ok));
    });

    test('round trips through toJson', () {
      const WallSpatial wall = WallSpatial(tier: WallSpatialTier.ok, mapUrl: _mapUrl);

      expect(wall.toJson(), <String, Object?>{'tier': 'ok', 'map': _mapUrl});
      expect(WallSpatial.parse(wall.toJson()), wall);
    });
  });
}
