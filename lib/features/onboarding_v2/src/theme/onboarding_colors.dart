import 'package:flutter/material.dart';

class OnboardingColors {
  const OnboardingColors._();

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Colors.transparent;

  static const Color textPrimary = black;
  static const Color textOnDark = white;

  static const Color buttonBackground = white;
  static const Color buttonText = black;

  static const Color progressActive = black;

  static const Color surfaceGlass = white;
  static const Color selectionOverlay = black;

  /// Warm fill behind the welcome wallpaper so a failed decode cannot leave
  /// a white screen with a white CTA.
  static const Color fallbackFill = Color(0xFFF3C4B0);
}
