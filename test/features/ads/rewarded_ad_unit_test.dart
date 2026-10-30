import 'package:Prism/features/ads/data/rewarded_ad_unit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release iOS uses only its configured ad unit', () {
    expect(
      rewardedAdUnitId(isRelease: true, platform: TargetPlatform.iOS, iosAdUnitId: 'ios-rewarded-unit'),
      'ios-rewarded-unit',
    );
  });

  test('release iOS without a configured unit cannot fall back to Android or test ads', () {
    for (final value in ['', '   ']) {
      expect(rewardedAdUnitId(isRelease: true, platform: TargetPlatform.iOS, iosAdUnitId: value), isNull);
    }
  });

  test('release Android retains its production unit without iOS configuration', () {
    expect(
      rewardedAdUnitId(isRelease: true, platform: TargetPlatform.android, iosAdUnitId: ''),
      'ca-app-pub-4649644680694757/3358009164',
    );
  });

  test('debug Android uses the Google Android test unit', () {
    expect(
      rewardedAdUnitId(isRelease: false, platform: TargetPlatform.android, iosAdUnitId: 'ios-rewarded-unit'),
      'ca-app-pub-3940256099942544/5224354917',
    );
  });

  test('debug iOS uses the Google iOS test unit even without production configuration', () {
    expect(
      rewardedAdUnitId(isRelease: false, platform: TargetPlatform.iOS, iosAdUnitId: ''),
      'ca-app-pub-3940256099942544/1712485313',
    );
  });
}
