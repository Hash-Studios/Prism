import 'package:flutter/material.dart';

class OnboardingMotion {
  const OnboardingMotion._();

  static const Duration short = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration long = Duration(milliseconds: 450);
  static const Duration backgroundReveal = Duration(milliseconds: 5000);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve reveal = Curves.easeOutCubic;
}
