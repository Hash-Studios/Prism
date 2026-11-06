import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';

/// The long side of the image the palette is read from. The backend reads wall colours at the same size
/// (`functions/src/wallColors.ts`), so a photo and a wall get comparable palettes.
const int photoPaletteSampleSize = 48;
const double _minShare = 0.12;
const int _maxColours = 3;

/// The palette colours that cover at least 12% of [rgba], the largest first, at most 3. It always holds the top
/// colour. Transparent pixels are seen over white. The shares are scaled to add up to 1.
///
/// [rgba] is 4 bytes per pixel. It must hold at least one pixel.
List<PaletteShare> paletteOfPixels(Uint8List rgba) {
  final int pixels = rgba.length ~/ 4;
  if (pixels == 0) throw ArgumentError.value(rgba.length, 'rgba', 'holds no pixel');
  final Map<PrismPaletteColor, int> counts = <PrismPaletteColor, int>{};
  for (int i = 0; i < pixels * 4; i += 4) {
    final int alpha = rgba[i + 3];
    int overWhite(int channel) => (channel * alpha + 255 * (255 - alpha)) ~/ 255;
    final PrismPaletteColor nearest = nearestPaletteColor(
      Color.fromARGB(255, overWhite(rgba[i]), overWhite(rgba[i + 1]), overWhite(rgba[i + 2])),
    );
    counts[nearest] = (counts[nearest] ?? 0) + 1;
  }
  final List<PrismPaletteColor> ranked = prismPalette.where(counts.containsKey).toList()
    ..sort((a, b) {
      final int byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : prismPalette.indexOf(a).compareTo(prismPalette.indexOf(b));
    });
  final List<PrismPaletteColor> picked = ranked
      .where((color) => counts[color]! / pixels >= _minShare)
      .take(_maxColours)
      .toList();
  if (picked.isEmpty) picked.add(ranked.first);
  final int total = picked.fold(0, (sum, color) => sum + counts[color]!);
  return <PaletteShare>[for (final PrismPaletteColor color in picked) (color: color, share: counts[color]! / total)];
}

/// [paletteOfPixels] off the UI isolate. The 48 px sample is at most 9 KB, so the copy into the isolate is small.
Future<List<PaletteShare>> paletteOfPixelsInIsolate(Uint8List rgba) => Isolate.run(() => paletteOfPixels(rgba));
