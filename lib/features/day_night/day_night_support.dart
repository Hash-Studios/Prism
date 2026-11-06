import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:flutter/foundation.dart';

bool? _supported;

/// iOS runs Day and night through the Shortcuts action, so it needs iOS 16 or later. Android runs it with the
/// async_wallpaper daily schedule.
Future<bool> dayNightSupported() async => _supported ??=
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS && await iosSupportsShortcuts());

/// The answer of [dayNightSupported] once it has run, false before. Menus read it while they open.
bool get dayNightSupportedNow => _supported ?? false;

@visibleForTesting
set dayNightSupportedOverride(bool? value) => _supported = value;
