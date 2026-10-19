import 'dart:async';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_toast.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Platform-toast fallback colours, used only before the app's overlay exists.
const Color _fallbackSuccess = Color(0xFF2E7D32);
const Color _fallbackError = Color(0xFFC62828);
const Color _fallbackNeutral = Color(0xFF2B2B31);

/// Returns the app's root overlay. Set once at startup by `main.dart`. Until then, and in tests, toasts fall back to
/// the platform toast.
OverlayState? Function()? overlayResolver;

void _show(
  String msg,
  PrismToastKind kind,
  Color fallbackBackground, {
  Color? color,
  ToastGravity gravity = ToastGravity.BOTTOM,
  Color textColor = Colors.white,
}) {
  final OverlayState? overlay = overlayResolver?.call();
  if (overlay != null && overlay.mounted) {
    showPrismToast(overlay, msg, kind: kind, color: color);
    return;
  }
  // Channel calls keep their order, so the old toast is gone before the new one shows.
  unawaited(Fluttertoast.cancel());
  unawaited(
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: gravity,
      textColor: textColor,
      backgroundColor: fallbackBackground,
    ),
  );
}

void success(String msg, {bool haptic = true}) {
  if (haptic) PrismHaptics.success();
  _show(msg, PrismToastKind.success, _fallbackSuccess);
}

void error(String msg, {bool haptic = true}) {
  if (haptic) PrismHaptics.error();
  _show(msg, PrismToastKind.error, _fallbackError);
}

/// A neutral note: not a success and not an error.
void info(String msg) => _show(msg, PrismToastKind.plain, _fallbackNeutral);

void color(Color color, {required String message}) => _show(
  message,
  PrismToastKind.plain,
  color,
  color: color,
  gravity: ToastGravity.CENTER,
  textColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
);
