import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Brightness of the dominant colour of the image at [url], or null when it cannot be read.
Future<Brightness?> wallpaperBrightness(String url) async {
  try {
    final palette = await PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(url), maximumColorCount: 8);
    return ThemeData.estimateBrightnessForColor(palette.dominantColor?.color ?? Colors.black);
  } catch (_) {
    return null;
  }
}
