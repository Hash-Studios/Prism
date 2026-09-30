import 'package:Prism/core/widgets/prism/prism_toast.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_LONG,
    gravity: gravity,
    textColor: textColor,
    backgroundColor: fallbackBackground,
  );
}

void success(String msg) => _show(msg, PrismToastKind.success, Colors.green[400]!);

void error(String msg) => _show(msg, PrismToastKind.error, Colors.red[400]!);

void color(Color color) => _show(
  'Color code copied to clipboard',
  PrismToastKind.plain,
  color,
  color: color,
  gravity: ToastGravity.CENTER,
  textColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
);
