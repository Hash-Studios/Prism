import 'dart:ui' show FlutterView, PlatformDispatcher;

import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/services.dart';

/// Orientations the app allows for a window of [size]: portrait on a phone, any orientation on a tablet or an
/// unfolded foldable. An empty list lets the platform decide.
List<DeviceOrientation> allowedOrientations(Size size) =>
    size.shortestSide < PrismLayout.tabletShortestSide ? const [DeviceOrientation.portraitUp] : const [];

List<DeviceOrientation>? _applied;

/// Sends [allowedOrientations] for the main window to the platform when they change. Call it at startup and on every
/// metrics change, so a foldable that folds to phone size goes back to portrait.
Future<void> applyAllowedOrientations() async {
  final FlutterView? view = PlatformDispatcher.instance.implicitView;
  final Size size = view == null ? Size.zero : view.physicalSize / view.devicePixelRatio;
  final List<DeviceOrientation> next = allowedOrientations(size);
  if (identical(next, _applied)) return;
  _applied = next;
  await SystemChrome.setPreferredOrientations(next);
}
