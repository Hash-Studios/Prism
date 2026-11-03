import 'package:Prism/core/platform/install_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void _mockInstaller(String? installerStore) {
  PackageInfo.setMockInitialValues(
    appName: 'Prism',
    packageName: 'com.hash.prism',
    version: '3.18.2',
    buildNumber: '359',
    buildSignature: '',
    installerStore: installerStore,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('apkDownloadOffered fails closed when reading the installer throws', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall methodCall,
    ) {
      return Future<Object?>.error(PlatformException(code: 'installer_unavailable'));
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    expect(await apkDownloadOffered(), isFalse);
  });

  test('offersApkDownload offers the APK only to Android installs that Play did not make', () {
    final cases = <({TargetPlatform platform, String? installer, bool expected})>[
      (platform: TargetPlatform.android, installer: 'com.android.vending', expected: false),
      (platform: TargetPlatform.android, installer: null, expected: true),
      (platform: TargetPlatform.android, installer: 'com.google.android.packageinstaller', expected: true),
      (platform: TargetPlatform.android, installer: 'com.aurora.store', expected: true),
      (platform: TargetPlatform.iOS, installer: null, expected: false),
      (platform: TargetPlatform.iOS, installer: 'com.android.vending', expected: false),
    ];
    for (final c in cases) {
      expect(
        offersApkDownload(platform: c.platform, installer: c.installer),
        c.expected,
        reason: '${c.platform} with installer ${c.installer}',
      );
    }
  });

  test('apkDownloadOffered is true for a sideloaded install', () async {
    _mockInstaller(null);
    expect(await apkDownloadOffered(), isTrue);
  });

  test('apkDownloadOffered is false for a Play install', () async {
    _mockInstaller('com.android.vending');
    expect(await apkDownloadOffered(), isFalse);
  });
}
