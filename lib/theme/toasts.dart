import 'dart:async';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void _show(String msg, Color background, {ToastGravity gravity = ToastGravity.BOTTOM, Color textColor = Colors.white}) {
  // Channel calls keep their order, so the old toast is gone before the new one shows.
  unawaited(Fluttertoast.cancel());
  unawaited(
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: gravity,
      textColor: textColor,
      backgroundColor: background,
    ),
  );
}

void success(String msg, {bool haptic = true}) {
  if (haptic) PrismHaptics.success();
  _show(msg, Colors.green[800]!);
}

void error(String msg, {bool haptic = true}) {
  if (haptic) PrismHaptics.error();
  _show(msg, Colors.red[700]!);
}

void info(String msg) => _show(msg, Colors.grey[850]!);

void color(Color color) => _show(
  'Color code copied to clipboard',
  color,
  gravity: ToastGravity.CENTER,
  textColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
);
