import 'package:Prism/core/utils/orientation_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phones stay in portrait', () {
    for (final Size size in const <Size>[Size(320, 568), Size(393, 852), Size(440, 956), Size(599, 900)]) {
      expect(allowedOrientations(size), const <DeviceOrientation>[DeviceOrientation.portraitUp], reason: '$size');
    }
  });

  test('tablets turn in either orientation', () {
    for (final Size size in const <Size>[Size(744, 1133), Size(1032, 1376), Size(1376, 1032), Size(1280, 800)]) {
      expect(allowedOrientations(size), isEmpty, reason: '$size');
    }
  });

  test('a phone held sideways is still a phone', () {
    expect(allowedOrientations(const Size(852, 393)), const <DeviceOrientation>[DeviceOrientation.portraitUp]);
  });
}
