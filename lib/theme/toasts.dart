import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void codeSend(String msg) {
  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      backgroundColor: Colors.green[400],
      fontSize: 16.0);
}

void error(String msg) {
  Fluttertoast.showToast(
    msg: msg,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    textColor: Colors.white,
    backgroundColor: Colors.red[400],
    fontSize: 16.0,
  );
}

void color(Color color) {
  Fluttertoast.showToast(
    msg: "Color code copied to clipboard",
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    textColor: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    backgroundColor: color,
    fontSize: 16.0,
  );
}
