import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppData {
  static final AppData _appData = new AppData._internal();

  bool isPro;

  factory AppData() {
    return _appData;
  }
  AppData._internal();
}

final appData = AppData();

// var kWelcomeAlertStyle = AlertStyle(
//   animationType: AnimationType.grow,
//   isCloseButton: false,
//   isOverlayTapDismiss: false,
//   animationDuration: Duration(milliseconds: 450),
//   alertBorder: RoundedRectangleBorder(
//     borderRadius: BorderRadius.circular(10.0),
//   ),
//   titleStyle: TextStyle(
//     fontWeight: FontWeight.bold,
//     fontSize: 30.0,
//     letterSpacing: 1.5,
//   ),
// );

TextStyle kSendButtonTextStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 20,
);
