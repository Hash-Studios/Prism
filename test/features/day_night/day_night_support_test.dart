import 'package:Prism/features/day_night/day_night_support.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    dayNightSupportedOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android supports Day and night, and the sync answer follows once it has run', () async {
    dayNightSupportedOverride = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(await dayNightSupported(), isTrue);
    expect(dayNightSupportedNow, isTrue);
  });
}
