import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
// ignore: implementation_imports
import 'package:lottie/src/model/key_path.dart';

const int _size = 256;

const Map<String, (double, double)> _markers = <String, (double, double)>{
  'idle': (0, 120),
  'charge': (120, 60),
  'open': (180, 90),
  'opened': (270, 120),
  'spent': (390, 2),
};

const List<String> _dynamicFills = <String>['glow', 'accent_light', 'accent_mid', 'accent_dark'];

/// Frame, fill and colour that must appear on screen once the fill is overridden.
const Map<String, double> _frameOf = <String, double>{
  'glow': 330,
  'accent_light': 0,
  'accent_mid': 0,
  'accent_dark': 0,
};

int _resolved(LottieComposition composition, List<String> keys) {
  final List<KeyPath> found = <KeyPath>[];
  LottieDrawable(composition).compositionLayer.resolveKeyPath(KeyPath(keys), 0, found, KeyPath(<String>[]));
  return found.length;
}

Future<ByteData> _render(
  LottieComposition composition,
  double frame, [
  List<ValueDelegate> values = const <ValueDelegate>[],
]) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  LottieDrawable(composition)
    ..delegates = LottieDelegates(values: values)
    ..setProgress(frame / composition.durationFrames)
    ..draw(ui.Canvas(recorder), const Rect.fromLTWH(0, 0, 256, 256));
  final ui.Image image = await recorder.endRecording().toImage(_size, _size);
  final ByteData data = (await image.toByteData())!;
  image.dispose();
  return data;
}

int _countRed(ByteData data) {
  int count = 0;
  for (int i = 0; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) > 120 &&
        data.getUint8(i + 1) < 70 &&
        data.getUint8(i + 2) < 70 &&
        data.getUint8(i + 3) > 200) {
      count++;
    }
  }
  return count;
}

int _maxDelta(ByteData a, ByteData b) {
  int most = 0;
  for (int i = 0; i < a.lengthInBytes; i++) {
    final int delta = (a.getUint8(i) - b.getUint8(i)).abs();
    if (delta > most) most = delta;
  }
  return most;
}

int _luma(ByteData data, int x, int y) {
  final int i = (y * _size + x) * 4;
  return (data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2)) ~/ 3;
}

void main() {
  late LottieComposition composition;

  setUpAll(() async {
    composition = await LottieComposition.fromBytes(File('assets/lottie/daily_chest.json').readAsBytesSync());
  });

  test('is a 512 by 512 composition of 393 frames at 60 fps', () {
    expect(composition.bounds.width, 512);
    expect(composition.bounds.height, 512);
    expect(composition.frameRate, 60);
    // Lottie Flutter reads the out point 393 as 392.99.
    expect(composition.durationFrames, closeTo(392.99, 0.001));
  });

  test('has exactly the five markers, each inside the composition', () {
    expect(composition.markers.map((Marker m) => m.name), <String>['idle', 'charge', 'open', 'opened', 'spent']);
    for (final MapEntry<String, (double, double)> expected in _markers.entries) {
      final Marker marker = composition.getMarker(expected.key)!;
      expect((marker.startFrame, marker.durationFrames), expected.value, reason: expected.key);
      expect(marker.startFrame + marker.durationFrames, lessThanOrEqualTo(composition.endFrame), reason: expected.key);
    }
  });

  test('resolves the dynamic fill names to content and nothing for an unknown name', () {
    for (final String name in _dynamicFills) {
      expect(_resolved(composition, <String>['**', name]), greaterThan(0), reason: name);
    }
    expect(_resolved(composition, <String>['**', 'no_such_fill']), 0);
  });

  test('a colour override reaches the screen for every dynamic fill', () async {
    for (final String name in _dynamicFills) {
      final double frame = _frameOf[name]!;
      final ByteData plain = await _render(composition, frame);
      final ByteData tinted = await _render(composition, frame, <ValueDelegate>[
        ValueDelegate.color(<String>['**', name], value: const Color(0xFFFF0000)),
      ]);
      expect(_countRed(plain), 0, reason: '$name default');
      expect(_countRed(tinted), greaterThan(300), reason: '$name override');
    }
  });

  test('every loop marker starts and ends on the same picture', () async {
    // Lottie Flutter reads eased keys from a lookup table, so the two ends differ by about a tenth of a pixel.
    for (final (double, double) loop in <(double, double)>[(0, 120), (120, 180), (270, 390)]) {
      final ByteData first = await _render(composition, loop.$1);
      final ByteData last = await _render(composition, loop.$2);
      expect(_maxDelta(first, last), lessThanOrEqualTo(32), reason: 'frames ${loop.$1} and ${loop.$2}');
    }
    expect(_maxDelta(await _render(composition, 0), await _render(composition, 60)), greaterThan(100));
  });

  test('the opened box has a bright core and the spent box does not', () async {
    expect(_luma(await _render(composition, 330), 128, 110), greaterThan(225));
    expect(_luma(await _render(composition, 392), 128, 110), lessThan(110));
  });
}
