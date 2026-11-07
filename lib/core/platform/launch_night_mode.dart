import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('prism/launch_theme');
ThemeMode? _latestMode;
int _generation = 0;

/// Android 12+ use the persisted app night mode for the splash and current Activity configuration.
Future<void> syncLaunchNightMode(ThemeMode mode) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  _latestMode = mode;
  final int generation = ++_generation;
  _channel.setMethodCallHandler((call) async {
    if (call.method != 'ready') throw MissingPluginException();
    final ThemeMode? latest = _latestMode;
    if (latest != null) await syncLaunchNightMode(latest);
  });
  for (int attempt = 0; attempt < 2; attempt++) {
    if (generation != _generation) return;
    try {
      await _channel.invokeMethod<void>('setNightMode', mode.name);
      return;
    } on PlatformException {
      return;
    } on MissingPluginException {
      if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
