import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppData {
  AppData._();
  static String? get font => GoogleFonts.sora().fontFamily;
  static VisualDensity get visualDensity =>
      FlexColorScheme.comfortablePlatformDensity;
}
