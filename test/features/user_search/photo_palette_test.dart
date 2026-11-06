import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/user_search/data/photo_palette.dart';
import 'package:flutter_test/flutter_test.dart';

/// Packs [pixels] of [r, g, b, a] into a byte buffer, 4 bytes per pixel.
Uint8List rgba(List<List<int>> pixels) => Uint8List.fromList(<int>[for (final List<int> p in pixels) ...p]);

/// 1536 red pixels, then 768 white pixels: 2304 pixels, a 48 px sample.
Uint8List redThenWhite() => rgba(<List<int>>[
  for (int i = 0; i < 1536; i++) <int>[0xcc, 0, 0, 255],
  for (int i = 0; i < 768; i++) <int>[255, 255, 255, 255],
]);

/// Position of the palette colour [id] in [prismPalette].
int paletteIndex(String id) => prismPalette.indexWhere((color) => color.id == id);

void main() {
  test('one solid colour', () {
    final Uint8List pixels = rgba(<List<int>>[
      for (int i = 0; i < 48 * 48; i++) <int>[0x00, 0x66, 0xcc, 255],
    ]);

    final result = paletteOfPixels(pixels);

    expect(result, hasLength(1));
    expect(result.single.color.id, 'blue');
    expect(result.single.share, 1.0);
  });

  test('two colours', () {
    final result = paletteOfPixels(redThenWhite());

    expect(result.map((e) => e.color.id).toList(), <String>['red', 'white']);
    expect(result[0].share, closeTo(2 / 3, 1e-9));
    expect(result[1].share, closeTo(1 / 3, 1e-9));
    expect(result.fold<double>(0, (sum, e) => sum + e.share), closeTo(1, 1e-9));
  });

  test('a gradient keeps only colours over 12%, at most 3, largest first', () {
    final Uint8List pixels = Uint8List(256 * 4);
    final Map<String, int> counts = <String, int>{};
    for (int i = 0; i < 256; i++) {
      pixels.setRange(i * 4, i * 4 + 4, <int>[i, i, i, 255]);
      final String id = nearestPaletteColor(Color.fromARGB(255, i, i, i)).id;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final List<String> computed =
        <String>[
          for (final PrismPaletteColor color in prismPalette)
            if (counts.containsKey(color.id) && counts[color.id]! / 256 >= 0.12) color.id,
        ]..sort((a, b) {
          final int byCount = counts[b]!.compareTo(counts[a]!);
          return byCount != 0 ? byCount : paletteIndex(a).compareTo(paletteIndex(b));
        });
    final List<String> expected = computed.take(3).toList();

    final result = paletteOfPixels(pixels);

    expect(result.length, lessThanOrEqualTo(3));
    expect(result.map((e) => e.color.id).toList(), expected);
    expect(result.map((e) => e.color.id).toList(), <String>['grey', 'black', 'white']);
    expect(result.fold<double>(0, (sum, e) => sum + e.share), closeTo(1, 1e-9));
  });

  test('a tiny colour under 12% is dropped', () {
    final Uint8List pixels = rgba(<List<int>>[
      for (int i = 0; i < 95; i++) <int>[0, 0, 0, 255],
      for (int i = 0; i < 5; i++) <int>[0xff, 0xcc, 0x33, 255],
    ]);

    final result = paletteOfPixels(pixels);

    expect(result.map((e) => e.color.id).toList(), <String>['black']);
    expect(result.single.share, 1.0);
  });

  test('when no colour reaches 12% the top colour is kept', () {
    final List<List<int>> pixels = <List<int>>[];
    for (int k = 0; k < prismPalette.length; k++) {
      final Color c = prismPalette[k].color;
      final int count = switch (k) {
        0 => 11,
        1 => 9,
        _ => 8,
      };
      for (int j = 0; j < count; j++) {
        pixels.add(<int>[(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), 255]);
      }
    }
    expect(pixels, hasLength(100));

    final result = paletteOfPixels(rgba(pixels));

    expect(result, hasLength(1));
    expect(result.single.color.id, prismPalette.first.id);
    expect(result.single.color.id, 'red');
  });

  test('transparent pixels count as white', () {
    final Uint8List pixels = rgba(<List<int>>[
      for (int i = 0; i < 10; i++) <int>[0, 0, 0, 0],
    ]);

    final result = paletteOfPixels(pixels);

    expect(result.map((e) => e.color.id).toList(), <String>['white']);
  });

  test('an empty buffer throws', () {
    expect(() => paletteOfPixels(Uint8List(0)), throwsArgumentError);
  });

  test('the isolate gives the same answer', () async {
    final result = await paletteOfPixelsInIsolate(redThenWhite());

    expect(result.map((e) => e.color.id).toList(), <String>['red', 'white']);
  });
}
