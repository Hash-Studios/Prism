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

TextStyle kSendButtonTextStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 20,
);
