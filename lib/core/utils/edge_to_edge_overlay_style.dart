import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle edgeToEdgeOverlayStyle({required Brightness statusBarIconBrightness}) {
  final statusBarBrightness = statusBarIconBrightness == Brightness.dark ? Brightness.light : Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarIconBrightness: statusBarIconBrightness,
    statusBarBrightness: statusBarBrightness,
    systemNavigationBarIconBrightness: statusBarIconBrightness,
  );
}

void applyEdgeToEdgeOverlayStyle({required Brightness statusBarIconBrightness}) {
  if (!kIsWeb && Platform.isAndroid) {
    return;
  }
  SystemChrome.setSystemUIOverlayStyle(edgeToEdgeOverlayStyle(statusBarIconBrightness: statusBarIconBrightness));
}
