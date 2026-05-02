import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle edgeToEdgeOverlayStyle({
  required Brightness statusBarIconBrightness,
  Brightness? systemNavigationBarIconBrightness,
}) {
  final statusBarBrightness = statusBarIconBrightness == Brightness.dark ? Brightness.light : Brightness.dark;
  final navBarIconBrightness = systemNavigationBarIconBrightness ?? statusBarIconBrightness;

  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: statusBarIconBrightness,
    statusBarBrightness: statusBarBrightness,
    systemNavigationBarColor: const Color(0x00000000),
    systemNavigationBarDividerColor: const Color(0x00000000),
    systemNavigationBarIconBrightness: navBarIconBrightness,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}

void applyEdgeToEdgeOverlayStyle({
  required Brightness statusBarIconBrightness,
  Brightness? systemNavigationBarIconBrightness,
}) {
  if (kIsWeb) {
    return;
  }
  SystemChrome.setSystemUIOverlayStyle(
    edgeToEdgeOverlayStyle(
      statusBarIconBrightness: statusBarIconBrightness,
      systemNavigationBarIconBrightness: systemNavigationBarIconBrightness,
    ),
  );
}
