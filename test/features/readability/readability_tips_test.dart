import 'dart:ui' as ui;

import 'package:Prism/features/readability/data/readability_tips.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const ReadabilityFix _clockDim = ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim);

ReadabilityKey _key({
  String wall = 'wall-1',
  String image = '/tmp/wall-1.png',
  WallpaperPlacement? placement = const WallpaperPlacement(),
  int? tint,
  TargetPlatform platform = TargetPlatform.android,
  int clockText = 0xFFFFFFFF,
  int frameHeight = 234,
}) => (
  wall: wall,
  image: image,
  placement: placement,
  tint: tint,
  platform: platform,
  clockText: clockText,
  frameHeight: frameHeight,
);

Map<ReadabilityZone, ReadabilityResult> _fixedResult() => <ReadabilityZone, ReadabilityResult>{
  ReadabilityZone.clock: const ReadabilityResult(
    zone: ReadabilityZone.clock,
    lowContrastShare: 0.5,
    edgeShare: 0,
    fix: ReadabilityFixKind.dim,
  ),
  ReadabilityZone.icons: const ReadabilityResult(zone: ReadabilityZone.icons, lowContrastShare: 0, edgeShare: 0),
};

Future<ui.Image> _solid(Color color) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 80), Paint()..color = color);
  return recorder.endRecording().toImage(40, 80);
}

/// Runs [ReadabilityTips.instance.check] for [key], decoding a white 40 x 80 wall on a cache miss.
Future<Map<ReadabilityZone, ReadabilityResult>> _check(ReadabilityKey key, {VoidCallback? onDecode}) =>
    ReadabilityTips.instance.check(key, () {
      onDecode?.call();
      return _solid(const Color(0xFFFFFFFF));
    }, tint: key.tint == null ? null : Color(key.tint!));

void main() {
  late int analyzerCalls;

  setUp(() {
    ReadabilityTips.useIsolate = false;
    analyzerCalls = 0;
    ReadabilityTips.analyzer =
        (
          ReadabilityFrame frame, {
          required TargetPlatform platform,
          Map<ReadabilityZone, ui.Color> textColors = const {},
        }) {
          analyzerCalls++;
          return _fixedResult();
        };
  });

  tearDown(() {
    ReadabilityTips.analyzer = analyzeReadability;
    ReadabilityTips.useIsolate = true;
    ReadabilityTips.instance.reset();
  });

  testWidgets('an equal key is analyzed once and decoded once', (tester) async {
    await tester.runAsync(() async {
      int decodes = 0;
      final ReadabilityKey key = _key();
      final Map<ReadabilityZone, ReadabilityResult> first = await _check(key, onDecode: () => decodes++);
      final Map<ReadabilityZone, ReadabilityResult> second = await _check(key, onDecode: () => decodes++);
      expect(analyzerCalls, 1);
      expect(decodes, 1);
      expect(second, same(first));
    });
  });

  testWidgets('the default analyzer runs in an isolate with its decoded frame payload', (tester) async {
    await tester.runAsync(() async {
      ReadabilityTips.analyzer = analyzeReadability;
      ReadabilityTips.useIsolate = true;
      final Map<ReadabilityZone, ReadabilityResult> result = await _check(_key());
      expect(result[ReadabilityZone.clock]?.fix, ReadabilityFixKind.dim);
      expect(result[ReadabilityZone.icons]?.fix, ReadabilityFixKind.dim);
    });
  });

  testWidgets('a key that differs in one field misses the cache', (tester) async {
    await tester.runAsync(() async {
      await _check(_key());
      expect(analyzerCalls, 1);

      final List<ReadabilityKey> variants = <ReadabilityKey>[
        _key(tint: 0xFF0000FF),
        _key(placement: const WallpaperPlacement(dim: 0.2)),
        _key(image: '/tmp/other.png'),
        _key(platform: TargetPlatform.iOS),
      ];
      for (int i = 0; i < variants.length; i++) {
        await _check(variants[i]);
        expect(analyzerCalls, 2 + i, reason: 'variant ${i + 1} should miss the cache');
      }
    });
  });

  test('keys with equal fields are equal, and placement fixes make a key differ', () {
    expect(_key(), equals(_key()));
    expect(_key(placement: const WallpaperPlacement(fixes: <ReadabilityFix>[_clockDim])), isNot(equals(_key())));
  });

  testWidgets('an analyzer that throws makes check throw and still disposes the decoded image', (tester) async {
    await tester.runAsync(() async {
      ReadabilityTips.analyzer =
          (
            ReadabilityFrame frame, {
            required TargetPlatform platform,
            Map<ReadabilityZone, ui.Color> textColors = const {},
          }) => throw StateError('analyzer failed');
      ui.Image? decoded;
      await expectLater(
        ReadabilityTips.instance.check(_key(), () async => decoded = await _solid(const Color(0xFFFFFFFF))),
        throwsStateError,
      );
      expect(decoded, isNotNull);
      expect(decoded!.debugDisposed, isTrue);
    });
  });

  test('shownFor is false until markShown, and reset clears it', () {
    final ReadabilityTips tips = ReadabilityTips.instance;
    expect(tips.shownFor('wall-1'), isFalse);
    tips.markShown('wall-1');
    expect(tips.shownFor('wall-1'), isTrue);
    tips.reset();
    expect(tips.shownFor('wall-1'), isFalse);
  });

  test('enabled is true when no SettingsLocalDataSource is registered', () {
    expect(ReadabilityTips.instance.enabled, isTrue);
  });
}
