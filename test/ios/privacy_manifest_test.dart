import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy manifest declares user defaults and file timestamp reasons', () {
    final String plist = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(plist, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    expect(plist, contains('CA92.1'));
    expect(plist, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    expect(plist, contains('C617.1'));
  });

  test('iOS registers the prism URL scheme', () {
    final String plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>prism</string>'));
  });
}
