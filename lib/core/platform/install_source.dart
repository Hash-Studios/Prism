import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

const String googlePlayInstaller = 'com.android.vending';

/// Google Play policy: a Play install updates only through Play, so it never links to the APK. iOS never does either.
/// An Android install with no installer, or any other installer, was sideloaded. See docs/features/public-apk.md.
bool offersApkDownload({required TargetPlatform platform, required String? installer}) =>
    platform == TargetPlatform.android && installer != googlePlayInstaller;

/// Whether this install shows the APK download page. PackageInfo caches the platform read.
Future<bool> apkDownloadOffered() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return offersApkDownload(platform: defaultTargetPlatform, installer: info.installerStore);
  } catch (error, stackTrace) {
    logger.w('Reading the installer failed. Hiding the APK link.', error: error, stackTrace: stackTrace);
    return false;
  }
}
