import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void _show(String msg, Color background, {ToastGravity gravity = ToastGravity.BOTTOM, Color textColor = Colors.white}) {
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_LONG,
    gravity: gravity,
    textColor: textColor,
    backgroundColor: background,
  );
}

void success(String msg) => _show(msg, Colors.green[400]!);

void error(String msg) => _show(msg, Colors.red[400]!);

void color(Color color) => _show(
  'Color code copied to clipboard',
  color,
  gravity: ToastGravity.CENTER,
  textColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
);
