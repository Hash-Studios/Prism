import 'dart:convert';

import 'package:Prism/features/daily_chest/domain/chest_phase.dart';
import 'package:Prism/features/daily_chest/views/widgets/chest_span.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// A one layer file of [frames] frames at [rate] fps with the given markers as (name, start, length) in frames.
Future<LottieComposition> _composition({
  required int rate,
  required int frames,
  required List<(String, int, int)> markers,
}) {
  final Map<String, Object?> json = <String, Object?>{
    'v': '5.7.0',
    'fr': rate,
    'ip': 0,
    'op': frames,
    'w': 512,
    'h': 512,
    'nm': 'test',
    'ddd': 0,
    'assets': <Object?>[],
    'layers': <Object?>[
      <String, Object?>{
        'ddd': 0,
        'ind': 1,
        'ty': 1,
        'nm': 'glow',
        'sr': 1,
        'ks': <String, Object?>{
          'o': <String, Object?>{'a': 0, 'k': 100},
          'r': <String, Object?>{'a': 0, 'k': 0},
          'p': <String, Object?>{
            'a': 0,
            'k': <int>[256, 256, 0],
          },
          'a': <String, Object?>{
            'a': 0,
            'k': <int>[0, 0, 0],
          },
          's': <String, Object?>{
            'a': 0,
            'k': <int>[100, 100, 100],
          },
        },
        'ao': 0,
        'sw': 512,
        'sh': 512,
        'sc': '#ffffff',
        'ip': 0,
        'op': frames,
        'st': 0,
        'bm': 0,
      },
    ],
    'markers': <Object?>[
      for (final (String name, int start, int length) in markers)
        <String, Object?>{'cm': name, 'tm': start, 'dr': length},
    ],
  };
  return LottieComposition.fromBytes(utf8.encode(jsonEncode(json)));
}

void main() {
  final ChestMarker open = chestMarkers[ChestPhase.opening]!;

  test('without a file the span comes from the contract frames at 60 fps', () {
    final ChestSpan span = ChestSpan.of(open, null);

    expect(span.from, closeTo(180 / 393, 1e-9));
    expect(span.to, closeTo(270 / 393, 1e-9));
    expect(span.duration, const Duration(milliseconds: 1500));
  });

  test('the burst sits 16 frames into the open span', () {
    final ChestSpan span = ChestSpan.of(open, null);

    expect(span.at(open, open.burstFrame!), closeTo(196 / 393, 1e-9));
  });

  test('with a file the span is read from its marker and its frame rate', () async {
    // The same frame numbers at 30 fps: the open span takes 3 s, not 1.5 s.
    final LottieComposition slow = await _composition(
      rate: 30,
      frames: 392,
      markers: <(String, int, int)>[('open', 180, 90)],
    );
    final ChestSpan span = ChestSpan.of(open, slow);

    expect(span.from, closeTo(180 / 392, 1e-3));
    expect(span.to, closeTo(270 / 392, 1e-3));
    expect(span.duration.inMilliseconds, closeTo(3000, 5));
  });

  test('a file that moved the marker moves the span', () async {
    final LottieComposition moved = await _composition(
      rate: 60,
      frames: 200,
      markers: <(String, int, int)>[('Open', 50, 60)],
    );
    final ChestSpan span = ChestSpan.of(open, moved);

    expect(span.from, closeTo(0.25, 1e-3));
    expect(span.to, closeTo(0.55, 1e-3));
    expect(span.duration.inMilliseconds, closeTo(1000, 5));
  });

  test('a file without the marker falls back to the contract frames', () async {
    final LottieComposition bare = await _composition(
      rate: 60,
      frames: 392,
      markers: <(String, int, int)>[('idle', 0, 120)],
    );
    final ChestSpan span = ChestSpan.of(open, bare);

    expect(span.from, closeTo(180 / 393, 1e-9));
    expect(span.duration, const Duration(milliseconds: 1500));
  });
}
