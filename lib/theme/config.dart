import 'package:flutter/material.dart';

class Colors {
  static const Color _mainColor = Color(0xFFFFFFFF);
  static const Color _secondColor = Color(0xFFEDEDED);
  static const Color _accentColor = Color(0xFF2F2F2F);
  static const Color _mainDarkColor = Color(0xFF000000);
  static const Color _secondDarkColor = Color(0xFF2F2F2F);
  static const Color _accentDarkColor = Color(0xFFF0F0F0);

  Color mainColor(double opacity) {
    return _mainColor.withValues(alpha: opacity);
  }

  Color secondColor(double opacity) {
    return _secondColor.withValues(alpha: opacity);
  }

  Color accentColor(double opacity) {
    return _accentColor.withValues(alpha: opacity);
  }

  Color mainDarkColor(double opacity) {
    return _mainDarkColor.withValues(alpha: opacity);
  }

  Color secondDarkColor(double opacity) {
    return _secondDarkColor.withValues(alpha: opacity);
  }

  Color accentDarkColor(double opacity) {
    return _accentDarkColor.withValues(alpha: opacity);
  }
}
