import 'package:flutter/material.dart';

extension ColorRgbHexX on Color {
  /// Six-digit RGB hex without alpha or `#`, as used by the SVG illustration templates.
  String get rgbHex => (toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
}
