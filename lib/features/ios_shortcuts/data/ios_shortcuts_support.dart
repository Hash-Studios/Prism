import 'package:Prism/logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// The first iOS major version that has the App Intents API behind "Get Prism Wallpaper".
const int iosShortcutsMinMajorVersion = 16;

Future<int?>? _majorVersion;

Future<int?> _readIosMajorVersion() async {
  try {
    final IosDeviceInfo info = await DeviceInfoPlugin().iosInfo;
    return int.tryParse(info.systemVersion.split('.').first);
  } catch (error, stackTrace) {
    logger.w('Could not read the iOS version', error: error, stackTrace: stackTrace);
    return null;
  }
}

/// The iOS major version, read once. `null` when it cannot be read. Tests replace it.
@visibleForTesting
Future<int?> Function() iosMajorVersion = () => _majorVersion ??= _readIosMajorVersion();

/// True when this iOS can run the Shortcuts action. An unreadable version counts as not supported.
Future<bool> iosSupportsShortcuts() async {
  final int? major = await iosMajorVersion();
  return major != null && major >= iosShortcutsMinMajorVersion;
}

/// The iOS major version, read once. `null` when it cannot be read.
Future<int?> iosMajor() => iosMajorVersion();

/// True when this iOS major version is at least [major]. An unreadable version counts as not supported.
Future<bool> iosAtLeast(int major) async => (await iosMajorVersion() ?? 0) >= major;
