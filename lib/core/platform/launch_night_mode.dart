import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('prism/launch_theme');

/// Android 12 and newer draw the launch splash before Dart runs, from the app night mode. Saves the in-app
/// theme mode there, so the next cold start shows a light splash for a light theme and a dark one for dark.
Future<void> syncLaunchNightMode(ThemeMode mode) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _channel.invokeMethod<void>('setNightMode', mode.name);
  } on PlatformException {
    return;
  } on MissingPluginException {
    return;
  }
}
