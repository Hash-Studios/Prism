import 'dart:async';
import 'dart:ui' show Display, FlutterView, PlatformDispatcher;

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

/// Logical size of the screen that shows [view], or null before it is known. The display comes first, because a
/// letterboxed window on a tablet is phone-sized. Android reports no display size, so the window is the fallback there.
Size? _screenSize(FlutterView view) {
  final Display display = view.display;
  if (!display.size.isEmpty && display.devicePixelRatio > 0) return display.size / display.devicePixelRatio;
  if (!view.physicalSize.isEmpty && view.devicePixelRatio > 0) return view.physicalSize / view.devicePixelRatio;
  return null;
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
