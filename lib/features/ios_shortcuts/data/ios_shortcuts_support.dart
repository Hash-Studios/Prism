import 'package:Prism/core/startup/firebase_init.dart';
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

/// Remote Config key for the iCloud link of the shared Prism shortcut. Empty hides the button.
const String iosShortcutLinkRemoteConfigKey = 'ios_shortcut_link';

/// The name of the shared shortcut. "Test it now" runs the shortcut with this name.
const String iosShortcutName = 'Prism Wallpaper';

@visibleForTesting
String? iosShortcutLinkOverride;

/// The shared shortcut's https link from Remote Config, or null when it is empty or not https.
Uri? iosShortcutLink() {
  final String raw =
      iosShortcutLinkOverride ??
      FirebaseInit.remoteConfigIfInitialized?.getString(iosShortcutLinkRemoteConfigKey) ??
      '';
  final Uri? uri = Uri.tryParse(raw.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? uri : null;
}

/// `shortcuts://run-shortcut?name=Prism%20Wallpaper`. Shortcuts reads `+` as a plus sign, so the space is `%20`.
Uri iosRunShortcutUri() => Uri.parse('shortcuts://run-shortcut?name=${Uri.encodeComponent(iosShortcutName)}');
