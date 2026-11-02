import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses every stored id and returns null for an unknown one', () {
    expect(WallMood.parse('duo_reveal'), WallMood.duoReveal);
    expect(WallMood.parse('dreamy'), WallMood.dreamy);
    expect(WallMood.parse('dark_quiet'), WallMood.darkQuiet);
    expect(WallMood.parse('bright_bold'), WallMood.brightBold);
    expect(WallMood.parse('minimal'), WallMood.minimal);
    expect(WallMood.parse('spatial_ready'), WallMood.spatialReady);
    expect(WallMood.parse('depth_ready'), WallMood.depthReady);
    expect(WallMood.parse('future_mood'), isNull);
    expect(WallMood.parse(null), isNull);
  });

  test('shows the four general moods everywhere', () {
    for (final WallMood mood in <WallMood>[
      WallMood.duoReveal,
      WallMood.dreamy,
      WallMood.darkQuiet,
      WallMood.brightBold,
      WallMood.minimal,
    ]) {
      expect(mood.shownOn(iosMajor: null), isTrue, reason: mood.id);
      expect(mood.shownOn(iosMajor: 0), isTrue, reason: mood.id);
      expect(mood.shownOn(iosMajor: 18), isTrue, reason: mood.id);
    }
  });

  test('shows spatial ready only on iOS 26 and later', () {
    expect(WallMood.spatialReady.shownOn(iosMajor: null), isFalse);
    expect(WallMood.spatialReady.shownOn(iosMajor: 18), isFalse);
    expect(WallMood.spatialReady.shownOn(iosMajor: 0), isFalse);
    expect(WallMood.spatialReady.shownOn(iosMajor: 26), isTrue);
  });

  test('shows depth ready only on iOS 16 and later', () {
    expect(WallMood.depthReady.shownOn(iosMajor: null), isFalse);
    expect(WallMood.depthReady.shownOn(iosMajor: 0), isFalse);
    expect(WallMood.depthReady.shownOn(iosMajor: 16), isTrue);
  });
}
