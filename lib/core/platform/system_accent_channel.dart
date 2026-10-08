import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The system accent colours of the phone, one per brightness.
@immutable
class SystemAccent {
  const SystemAccent({required this.light, required this.dark});

  final Color light;
  final Color dark;
}

/// Reads the Material You accent (Android 12 and up). Returns null on every other platform.
class SystemAccentChannel {
  const SystemAccentChannel();

  /// Settings key (in the `settings.` scope) for the "Match system colour" switch.
  static const String settingsKey = 'theme.system_accent';

  static const MethodChannel _channel = MethodChannel('prism/system_colors');

  Future<SystemAccent?> read() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final Map<Object?, Object?>? colors = await _channel.invokeMapMethod<Object?, Object?>('accent');
      final Object? light = colors?['light'];
      final Object? dark = colors?['dark'];
      if (light is! int || dark is! int) return null;
      return SystemAccent(light: Color(light), dark: Color(dark));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
