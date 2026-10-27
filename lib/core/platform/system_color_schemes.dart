import 'dart:async';

import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// The phone's Material You colour schemes, one per brightness. Android 12 and up builds them from the wallpaper.
@immutable
class SystemColorSchemes {
  const SystemColorSchemes({required this.light, required this.dark});

  final ColorScheme light;
  final ColorScheme dark;

  ColorScheme of(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  /// Null when [payload] is not a `{light, dark}` map of role maps, or either side has no `primary`.
  static SystemColorSchemes? fromPayload(Object? payload) {
    if (payload is! Map) return null;
    final ColorScheme? light = systemColorSchemeFromRoles(payload['light'], Brightness.light);
    final ColorScheme? dark = systemColorSchemeFromRoles(payload['dark'], Brightness.dark);
    if (light == null || dark == null) return null;
    return SystemColorSchemes(light: light, dark: dark);
  }

  @override
  bool operator ==(Object other) => other is SystemColorSchemes && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

/// A [ColorScheme] from a map of `ColorScheme` field names to ARGB ints. Roles the map lacks come from a scheme
/// seeded with its `primary`. Null without a `primary`.
ColorScheme? systemColorSchemeFromRoles(Object? roles, Brightness brightness) {
  if (roles is! Map) return null;
  Color? role(String name) {
    final Object? value = roles[name];
    return value is int ? Color(value) : null;
  }

  final Color? primary = role('primary');
  if (primary == null) return null;
  final ColorScheme seed = ColorScheme.fromSeed(seedColor: primary, brightness: brightness);
  return seed.copyWith(
    primary: primary,
    onPrimary: role('onPrimary'),
    primaryContainer: role('primaryContainer'),
    onPrimaryContainer: role('onPrimaryContainer'),
    primaryFixed: role('primaryFixed'),
    primaryFixedDim: role('primaryFixedDim'),
    onPrimaryFixed: role('onPrimaryFixed'),
    onPrimaryFixedVariant: role('onPrimaryFixedVariant'),
    secondary: role('secondary'),
    onSecondary: role('onSecondary'),
    secondaryContainer: role('secondaryContainer'),
    onSecondaryContainer: role('onSecondaryContainer'),
    secondaryFixed: role('secondaryFixed'),
    secondaryFixedDim: role('secondaryFixedDim'),
    onSecondaryFixed: role('onSecondaryFixed'),
    onSecondaryFixedVariant: role('onSecondaryFixedVariant'),
    tertiary: role('tertiary'),
    onTertiary: role('onTertiary'),
    tertiaryContainer: role('tertiaryContainer'),
    onTertiaryContainer: role('onTertiaryContainer'),
    tertiaryFixed: role('tertiaryFixed'),
    tertiaryFixedDim: role('tertiaryFixedDim'),
    onTertiaryFixed: role('onTertiaryFixed'),
    onTertiaryFixedVariant: role('onTertiaryFixedVariant'),
    error: role('error'),
    onError: role('onError'),
    errorContainer: role('errorContainer'),
    onErrorContainer: role('onErrorContainer'),
    surface: role('surface'),
    onSurface: role('onSurface'),
    surfaceDim: role('surfaceDim'),
    surfaceBright: role('surfaceBright'),
    surfaceContainerLowest: role('surfaceContainerLowest'),
    surfaceContainerLow: role('surfaceContainerLow'),
    surfaceContainer: role('surfaceContainer'),
    surfaceContainerHigh: role('surfaceContainerHigh'),
    surfaceContainerHighest: role('surfaceContainerHighest'),
    onSurfaceVariant: role('onSurfaceVariant'),
    outline: role('outline'),
    outlineVariant: role('outlineVariant'),
    shadow: role('shadow'),
    scrim: role('scrim'),
    inverseSurface: role('inverseSurface'),
    onInverseSurface: role('onInverseSurface'),
    inversePrimary: role('inversePrimary'),
    surfaceTint: role('surfaceTint'),
  );
}

/// Reads the schemes once. Null when the phone has none (iOS, Android 11 and lower). Throws when the read fails.
typedef SystemColorSchemesReader = Future<SystemColorSchemes?> Function();

const MethodChannel _channel = MethodChannel('prism/system_colors');

Future<SystemColorSchemes?> _readFromChannel() async {
  if (defaultTargetPlatform != TargetPlatform.android) return null;
  final Object? payload = await _channel.invokeMethod<Object?>('scheme');
  if (payload == null) return null;
  final SystemColorSchemes? schemes = SystemColorSchemes.fromPayload(payload);
  if (schemes == null) throw const FormatException('Malformed system colour scheme payload');
  return schemes;
}

/// The latest Material You schemes. A failed read keeps the last good value, so a theme never drops back mid-use.
@lazySingleton
class SystemColorSchemesSource {
  SystemColorSchemesSource() : this.withReader(_readFromChannel);

  @visibleForTesting
  SystemColorSchemesSource.withReader(
    this._read, {
    Future<void> Function(Duration) wait = Future<void>.delayed,
    this.retryInterval = const Duration(milliseconds: 500),
    this.retryLimit = const Duration(seconds: 6),
  }) : _wait = wait;

  final SystemColorSchemesReader _read;
  final Future<void> Function(Duration) _wait;
  final Duration retryInterval;
  final Duration retryLimit;
  final StreamController<SystemColorSchemes?> _changes = StreamController<SystemColorSchemes?>.broadcast();
  SystemColorSchemes? _current;

  SystemColorSchemes? get current => _current;

  Stream<SystemColorSchemes?> get changes => _changes.stream;

  /// Reads the schemes again. Returns the value it read, or the current one when the read failed.
  Future<SystemColorSchemes?> refresh() async {
    final SystemColorSchemes? read;
    try {
      read = await _read();
    } catch (error, stackTrace) {
      logger.w(
        'Material You colours could not be read; the fallback theme stays.',
        tag: 'Theme',
        error: error,
        stackTrace: stackTrace,
      );
      return _current;
    }
    if (read != _current) {
      _current = read;
      _changes.add(read);
    }
    return read;
  }

  /// Android recolours a few seconds after a new wallpaper. Reads every [retryInterval] until the schemes change
  /// or [retryLimit] passes. Returns whether they changed.
  Future<bool> refreshAfterWallpaperSet() async {
    final SystemColorSchemes? before = _current;
    final int attempts = retryLimit.inMilliseconds ~/ retryInterval.inMilliseconds;
    for (int attempt = 0; attempt < attempts; attempt++) {
      await _wait(retryInterval);
      if (_current != before) return true;
      final SystemColorSchemes? read = await refresh();
      if (read != null && read != before) return true;
    }
    return false;
  }
}
