import 'package:flutter/material.dart';

enum AiStylePreset {
  anime('anime', 'Anime', <Color>[Color(0xFFFF6B9D), Color(0xFF7C4DFF)]),
  minimal('minimal', 'Minimal', <Color>[Color(0xFFE0E0E0), Color(0xFFFAFAFA)]),
  cyberpunk('cyberpunk', 'Cyberpunk', <Color>[Color(0xFF00F5FF), Color(0xFF7C4DFF)]),
  watercolor('watercolor', 'Watercolor', <Color>[Color(0xFFFFB6C1), Color(0xFFE6E6FA)]),
  meshGradient('mesh gradient', 'Mesh Gradient', <Color>[Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D)]),
  abstract('abstract', 'Abstract', <Color>[Color(0xFFFF6B35), Color(0xFFD63031)]),
  nature('nature', 'Nature', <Color>[Color(0xFF00B894), Color(0xFF00CEC9)]),
  space('space art', 'Space', <Color>[Color(0xFF0B1D51), Color(0xFF6A4C93), Color(0xFFE0AAFF)]),
  synthwave('synthwave', 'Synthwave', <Color>[Color(0xFFFF2A6D), Color(0xFF2B0F54), Color(0xFF05D9E8)]),
  pixelArt('pixel art', 'Pixel Art', <Color>[Color(0xFF3EC1D3), Color(0xFFFF9A00), Color(0xFFFF165D)]),
  render3d('3d render', '3D Render', <Color>[Color(0xFFB8C6FF), Color(0xFFFFC8DD)]),
  oilPainting('oil painting', 'Oil Painting', <Color>[Color(0xFF8C5A3C), Color(0xFFE9C46A)]),
  ukiyoE('ukiyo-e', 'Ukiyo-e', <Color>[Color(0xFF1D3557), Color(0xFFE63946), Color(0xFFF1FAEE)]);

  const AiStylePreset(this.apiValue, this.label, this.swatchColors);

  final String apiValue;
  final String label;
  final List<Color> swatchColors;

  static String _key(String value) => value.trim().toLowerCase().replaceAll(RegExp('[ _]'), '');

  static AiStylePreset fromApiValue(String value) => tryFromApiValue(value) ?? abstract;

  static AiStylePreset? tryFromApiValue(String? value) {
    final String key = _key(value ?? '');
    if (key.isEmpty) return null;
    for (final AiStylePreset preset in values) {
      if (_key(preset.apiValue) == key) return preset;
    }
    return null;
  }
}
