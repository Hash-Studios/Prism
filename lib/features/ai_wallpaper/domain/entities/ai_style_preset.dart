import 'package:flutter/material.dart';

enum AiStylePreset {
  anime('anime', 'Anime', <Color>[Color(0xFFFF6B9D), Color(0xFF7C4DFF)]),
  minimal('minimal', 'Minimal', <Color>[Color(0xFFE0E0E0), Color(0xFFFAFAFA)]),
  cyberpunk('cyberpunk', 'Cyberpunk', <Color>[Color(0xFF00F5FF), Color(0xFF7C4DFF)]),
  watercolor('watercolor', 'Watercolor', <Color>[Color(0xFFFFB6C1), Color(0xFFE6E6FA)]),
  meshGradient('mesh gradient', 'Mesh Gradient', <Color>[Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D)]),
  abstract('abstract', 'Abstract', <Color>[Color(0xFFFF6B35), Color(0xFFD63031)]),
  nature('nature', 'Nature', <Color>[Color(0xFF00B894), Color(0xFF00CEC9)]);

  const AiStylePreset(this.apiValue, this.label, this.swatchColors);

  final String apiValue;
  final String label;
  final List<Color> swatchColors;

  static String _key(String value) => value.trim().toLowerCase().replaceAll(RegExp('[ _]'), '');

  static AiStylePreset fromApiValue(String value) {
    final String key = _key(value);
    return values.firstWhere((preset) => _key(preset.apiValue) == key, orElse: () => abstract);
  }
}
