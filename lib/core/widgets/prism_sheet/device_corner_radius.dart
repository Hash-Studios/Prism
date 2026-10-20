import 'dart:math' as math;
import 'dart:ui' show DisplayCornerRadii, FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

/// The bottom corner radius of the phone screen, in logical pixels.
///
/// Android 12 and later report it through `FlutterView.displayCornerRadii`, in physical pixels. iOS has no public
/// API, so `screen_corner_radius` reads it over a platform channel, in logical pixels. The channel is async, so the
/// first [resolve] starts the lookup and returns 0. [listenable] fires when the value arrives, so an open sheet can
/// repaint with the real curve.
// ignore: avoid_classes_with_only_static_members
abstract final class PrismDeviceCornerRadius {
  static final ValueNotifier<double?> _resolved = ValueNotifier<double?>(null);
  static Future<void>? _inFlight;

  /// Fires once the platform lookup completes.
  static ValueListenable<double?> get listenable => _resolved;

  /// Sets the resolved value. For tests only.
  @visibleForTesting
  static void setValueForTesting(double? radius) {
    _inFlight = Future<void>.value();
    _resolved.value = radius;
  }

  /// The radius to draw with. 0 until the platform answers.
  static double resolve(BuildContext context) {
    final FlutterView? view = View.maybeOf(context);
    final DisplayCornerRadii? native = view?.displayCornerRadii;
    if (view != null && native != null && view.devicePixelRatio > 0) {
      return math.max(native.bottomLeft, native.bottomRight) / view.devicePixelRatio;
    }
    _inFlight ??= _read();
    return _resolved.value ?? 0;
  }

  static Future<void> _read() async {
    try {
      final ScreenRadius? radii = await ScreenCornerRadius.get();
      if (radii != null) _resolved.value = math.max(radii.bottomLeft, radii.bottomRight);
    } on Object {
      // No implementation on this platform. Square corners are the safe fallback.
    }
  }
}
