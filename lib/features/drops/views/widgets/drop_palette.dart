import 'package:flutter/material.dart';

/// The fixed obsidian-and-champagne look of a Drop. Like the chest tiers, it keeps these colours on every theme, so
/// a Drop reads as one collectible object wherever it shows up.
abstract final class DropPalette {
  static const Color obsidian = Color(0xFF0B0B0D);
  static const Color obsidianRaised = Color(0xFF16161A);
  static const Color hairline = Color(0x33E9D7A8);
  static const Color goldLight = Color(0xFFF6E7B8);
  static const Color gold = Color(0xFFD9B66A);
  static const Color goldDeep = Color(0xFF8C6A2B);
  static const Color ink = Color(0xFFF4F1EA);
  static const Color inkMuted = Color(0x99F4F1EA);
  static const Color urgent = Color(0xFFFF6B5B);

  static const LinearGradient foil = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[goldDeep, gold, goldLight, gold, goldDeep],
    stops: <double>[0, 0.3, 0.5, 0.7, 1],
  );
}
