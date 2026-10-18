import 'dart:async';
import 'dart:ui' show FlutterView, PlatformDispatcher;

import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Orientations the app allows for a display of [size]: portrait on a phone, any orientation on a tablet or an
/// unfolded foldable. An empty list lets the platform decide.
List<DeviceOrientation> allowedOrientations(Size size) =>
    size.shortestSide < PrismLayout.tabletShortestSide ? const [DeviceOrientation.portraitUp] : const [];

List<DeviceOrientation>? _applied;

/// Sends [allowedOrientations] for the main window to the platform when they change. Call it at startup and on every
/// metrics change, so a foldable that folds to phone size goes back to portrait.
Future<void> applyAllowedOrientations({FlutterView? view}) async {
  final FlutterView? targetView = view ?? PlatformDispatcher.instance.implicitView;
  final Size displaySize = targetView?.display.size ?? Size.zero;
  final double? displayDevicePixelRatio = targetView?.display.devicePixelRatio;
  if (displaySize.isEmpty || displayDevicePixelRatio == null || displayDevicePixelRatio <= 0) return;

  final Size size = displaySize / displayDevicePixelRatio;
  final List<DeviceOrientation> next = allowedOrientations(size);
  if (identical(next, _applied)) return;
  _applied = next;
  try {
    await SystemChrome.setPreferredOrientations(next);
  } catch (_) {
    if (identical(_applied, next)) _applied = null;
    rethrow;
  }
}

class OrientationPolicyObserver with WidgetsBindingObserver {
  OrientationPolicyObserver({FlutterView? view}) : _view = view;

  final FlutterView? _view;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await applyAllowedOrientations(view: _view);
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeMetrics() => unawaited(applyAllowedOrientations(view: _view));
}
