import 'dart:typed_data';
import 'dart:ui' show Color, Rect;

import 'package:Prism/features/readability/domain/readability.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const int _w = analysisWidth;
const int _h = 234;

/// A frame where [grey] gives the 0 to 255 grey value of each pixel.
ReadabilityFrame _frame(int Function(int x, int y) grey) {
  final Uint8List rgba = Uint8List(_w * _h * 4);
  for (int y = 0; y < _h; y++) {
    for (int x = 0; x < _w; x++) {
      final int i = (y * _w + x) * 4;
      final int v = grey(x, y);
      rgba
        ..[i] = v
        ..[i + 1] = v
        ..[i + 2] = v
        ..[i + 3] = 255;
    }
  }
  return ReadabilityFrame(rgba: rgba, width: _w, height: _h);
}

final ReadabilityFrame _flatDark = _frame((_, _) => 20);
final ReadabilityFrame _flatLight = _frame((_, _) => 240);

/// Dark, but every pixel differs from its neighbour: fine detail with enough contrast for white text.
final ReadabilityFrame _busy = _frame((x, y) => (x + y).isEven ? 0 : 90);

/// A bright sky over the top 35 percent and dark ground below.
final ReadabilityFrame _skyTop = _frame((_, y) => y < _h * 0.35 ? 250 : 15);

Map<ReadabilityZone, ReadabilityFixKind?> _fixes(
  ReadabilityFrame frame,
  TargetPlatform platform, {
  Map<ReadabilityZone, Color> textColors = const <ReadabilityZone, Color>{},
}) => analyzeReadability(
  frame,
  platform: platform,
  textColors: textColors,
).map((zone, result) => MapEntry(zone, result.fix));

void main() {
  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
    group('on ${platform.name}', () {
      test('a flat dark wall is ok in every zone', () {
        expect(_fixes(_flatDark, platform), <ReadabilityZone, ReadabilityFixKind?>{
          ReadabilityZone.clock: null,
          ReadabilityZone.icons: null,
        });
      });

      test('a flat light wall needs a dim under white text', () {
        expect(_fixes(_flatLight, platform), <ReadabilityZone, ReadabilityFixKind?>{
          ReadabilityZone.clock: ReadabilityFixKind.dim,
          ReadabilityZone.icons: ReadabilityFixKind.dim,
        });
      });

      test('a flat light wall is ok for a clock the system draws in black', () {
        final Map<ReadabilityZone, ReadabilityFixKind?> fixes = _fixes(
          _flatLight,
          platform,
          textColors: <ReadabilityZone, Color>{ReadabilityZone.clock: const Color(0xFF000000)},
        );
        expect(fixes[ReadabilityZone.clock], isNull);
        expect(fixes[ReadabilityZone.icons], ReadabilityFixKind.dim);
      });

      test('a busy wall needs a blur', () {
        expect(_fixes(_busy, platform), <ReadabilityZone, ReadabilityFixKind?>{
          ReadabilityZone.clock: ReadabilityFixKind.blur,
          ReadabilityZone.icons: ReadabilityFixKind.blur,
        });
      });
    });
  }

  test('a bright sky at the top makes only the clock busy on Android', () {
    expect(_fixes(_skyTop, TargetPlatform.android), <ReadabilityZone, ReadabilityFixKind?>{
      ReadabilityZone.clock: ReadabilityFixKind.dim,
      ReadabilityZone.icons: null,
    });
  });

  test('a bright sky at the top also reaches the top icon rows on iOS', () {
    expect(_fixes(_skyTop, TargetPlatform.iOS), <ReadabilityZone, ReadabilityFixKind?>{
      ReadabilityZone.clock: ReadabilityFixKind.dim,
      ReadabilityZone.icons: ReadabilityFixKind.dim,
    });
  });

  test('zones are inside the screen, and each platform has its own set', () {
    for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
      for (final ReadabilityZone zone in ReadabilityZone.values) {
        for (final Rect rect in readabilityZoneRects(zone, platform)) {
          expect(rect.left >= 0 && rect.top >= 0 && rect.right <= 1 && rect.bottom <= 1, isTrue);
          expect(rect.isEmpty, isFalse);
        }
      }
    }
    expect(readabilityZoneRects(ReadabilityZone.clock, TargetPlatform.android), <Rect>[
      const Rect.fromLTRB(0.10, 0.07, 0.90, 0.30),
    ]);
    expect(readabilityZoneRects(ReadabilityZone.icons, TargetPlatform.iOS), hasLength(2));
    expect(
      readabilityZoneRects(ReadabilityZone.clock, TargetPlatform.iOS),
      isNot(readabilityZoneRects(ReadabilityZone.clock, TargetPlatform.android)),
    );
  });

  test('a frame smaller than 2 x 2 pixels is rejected', () {
    expect(
      () => analyzeReadability(
        ReadabilityFrame(rgba: Uint8List(4), width: 1, height: 1),
        platform: TargetPlatform.android,
      ),
      throwsArgumentError,
    );
  });

  test('one analysis of a frame takes well under 50 ms', () {
    analyzeReadability(_busy, platform: TargetPlatform.android);
    final Stopwatch timer = Stopwatch()..start();
    analyzeReadability(_busy, platform: TargetPlatform.android);
    expect(timer.elapsedMilliseconds, lessThan(50));
  });
}
