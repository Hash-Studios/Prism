import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Accent colours the user can pick from.
const List<Color> prismAccentSwatches = <Color>[
  Color(0xFFE57697),
  Color(0xFFFF0000),
  Color(0xFFF44436),
  Color(0xFFe91e63),
  Color(0xFF9c27b0),
  Color(0xFF673ab7),
  Color(0xFF0000FF),
  Color(0xFF1976D2),
  Color(0xFF03a9f4),
  Color(0xFF00bcd4),
  Color(0xFF009688),
  Color(0xFF4caf50),
  Color(0xFF00FF00),
  Color(0xFF8bc34a),
  Color(0xFFcddc39),
  Color(0xFFffeb3b),
  Color(0xFFffc107),
  Color(0xFFff9800),
  Color(0xFFff5722),
  Color(0xFF795548),
  Color(0xFF9e9e9e),
  Color(0xFF607d8b),
];

/// The colour family name of each swatch in [prismAccentSwatches], in the same order.
final List<String Function(AppLocalizations)> prismAccentSwatchNames = <String Function(AppLocalizations)>[
  (l) => l.coreColorPink,
  (l) => l.coreColorRed,
  (l) => l.coreColorRed,
  (l) => l.coreColorPink,
  (l) => l.coreColorPurple,
  (l) => l.coreColorPurple,
  (l) => l.coreColorBlue,
  (l) => l.coreColorBlue,
  (l) => l.coreColorBlue,
  (l) => l.coreColorTeal,
  (l) => l.coreColorTeal,
  (l) => l.coreColorGreen,
  (l) => l.coreColorGreen,
  (l) => l.coreColorGreen,
  (l) => l.coreColorGreen,
  (l) => l.coreColorYellow,
  (l) => l.coreColorYellow,
  (l) => l.coreColorOrange,
  (l) => l.coreColorOrange,
  (l) => l.coreColorBrown,
  (l) => l.coreColorGrey,
  (l) => l.coreColorGrey,
];
