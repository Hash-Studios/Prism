import 'package:flutter/material.dart';

extension AccentContrastX on Color {
  bool get isLight => computeLuminance() > 0.5;

  /// Black or white, whichever reads on top of this colour.
  Color get onColor => isLight ? Colors.black : Colors.white;
}
