import 'dart:async';
import 'dart:ui' show Display, FlutterView, PlatformDispatcher;

import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/foundation.dart';
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
  final Size? size = targetView == null ? null : _screenSize(targetView);
  if (size == null) return;
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

/// Logical size of the screen that shows [view], or null before it is known. The display is authoritative except on
/// iOS, where an unfolded iPhone Duo can have a window larger than its stale outer-display metrics. The window is
/// the fallback when display metrics are unavailable.
Size? _screenSize(FlutterView view) {
  final Display display = view.display;
  final Size? displaySize = !display.size.isEmpty && display.devicePixelRatio > 0
      ? display.size / display.devicePixelRatio
      : null;
  final Size? windowSize = !view.physicalSize.isEmpty && view.devicePixelRatio > 0
      ? view.physicalSize / view.devicePixelRatio
      : null;
  if (displaySize == null || windowSize == null) return displaySize ?? windowSize;
  if (defaultTargetPlatform == TargetPlatform.iOS && windowSize.shortestSide > displaySize.shortestSide) {
    return windowSize;
  }
  return displaySize;
}

/// Runs [applyAllowedOrientations] when it starts and on every metrics change.
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
