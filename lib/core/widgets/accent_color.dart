import 'package:flutter/material.dart';

/// The theme's accent (error) colour, swapped for the secondary colour on themes
/// where error is black and would vanish against a black background.
Color accentColor(BuildContext context) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return scheme.error == Colors.black ? scheme.secondary : scheme.error;
}
