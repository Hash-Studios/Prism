import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

/// The Material You colours Android would derive from [image]. Null when the image cannot be decoded.
Future<ColorScheme?> wallpaperScheme(ImageProvider image) async {
  try {
    return await ColorScheme.fromImageProvider(provider: ResizeImage(image, width: 64), brightness: Brightness.dark);
  } catch (error, stackTrace) {
    logger.w('wallpaperScheme: could not read the wallpaper colours', error: error, stackTrace: stackTrace);
    return null;
  }
}
