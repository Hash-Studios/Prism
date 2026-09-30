import 'package:Prism/core/widgets/prism/prism_toast.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Platform-toast fallback colours, used only before the app's overlay exists.
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
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_LONG,
    gravity: gravity,
    textColor: textColor,
    backgroundColor: fallbackBackground,
  );
}

void success(String msg) => _show(msg, PrismToastKind.success, PrismColors.success);

void error(String msg) => _show(msg, PrismToastKind.error, _fallbackError);

/// A neutral note: not a success and not an error.
void info(String msg) => _show(msg, PrismToastKind.plain, _fallbackNeutral);

void color(Color color) => _show(
  'Color code copied to clipboard',
  PrismToastKind.plain,
  color,
  color: color,
  gravity: ToastGravity.CENTER,
  textColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
);
