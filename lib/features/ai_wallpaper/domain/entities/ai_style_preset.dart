import 'package:Prism/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The stored sizes of each style sample: a 4:5 row tile (288x360) and a 9:16 sheet preview (540x960).
enum AiStyleSampleSize { tile, sheet }

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

  /// Bump with the version in tool/ai_style_samples.mjs when the samples are made again.
  static const String sampleVersion = 'v1';

  // The worker's studio route stores uploads only as flat `ai/studio/<name>` keys, so the version goes in the name.
  static const String _sampleBaseUrl = 'https://prismwalls.com/api/ai/assets/ai/studio';

  // Debug builds with AI_STYLE_SAMPLES_LOCAL only. Debug builds allow cleartext to localhost.
  static const String _localSampleBaseUrl = 'http://localhost:8765';

  /// [apiValue] as a key part: 'mesh gradient' is 'mesh-gradient'. tool/ai_style_samples.mjs uses the same rule.
  String get sampleSlug => apiValue.replaceAll(RegExp('[^a-z0-9]+'), '-');

  /// The one place that builds a sample URL. tool/ai_style_samples.mjs uploads to the same keys.
  String sampleUrl(AiStyleSampleSize size) {
    final String base = kDebugMode && Env.aiStyleSamplesLocal ? _localSampleBaseUrl : _sampleBaseUrl;
    return '$base/style-samples-$sampleVersion-$sampleSlug-${size.name}.webp';
  }

  static String _key(String value) => value.trim().toLowerCase().replaceAll(RegExp('[ _]'), '');

  static AiStylePreset fromApiValue(String value) {
    final String key = _key(value);
    return values.firstWhere((preset) => _key(preset.apiValue) == key, orElse: () => abstract);
  }
}
