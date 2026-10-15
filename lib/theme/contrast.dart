import 'package:flutter/material.dart';

/// Black or white, whichever reads on top of [background].
Color onColor(Color background) => background.computeLuminance() > 0.179 ? Colors.black : Colors.white;

/// WCAG contrast ratio between two opaque colours, from 1 (identical) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final double first = a.computeLuminance();
  final double second = b.computeLuminance();
  final double lighter = first > second ? first : second;
  final double darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
