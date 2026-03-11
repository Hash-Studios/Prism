import 'package:flutter/services.dart';

SystemUiOverlayStyle edgeToEdgeOverlayStyle({required Brightness statusBarIconBrightness}) {
  final statusBarBrightness = statusBarIconBrightness == Brightness.dark ? Brightness.light : Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarIconBrightness: statusBarIconBrightness,
    statusBarBrightness: statusBarBrightness,
    systemNavigationBarIconBrightness: statusBarIconBrightness,
  );
}
