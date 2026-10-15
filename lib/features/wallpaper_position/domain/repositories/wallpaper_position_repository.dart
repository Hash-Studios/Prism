import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';

/// A wall decoded for the studio.
class PlacementSource {
  const PlacementSource({required this.image, required this.dominantColor});

  final ui.Image image;

  /// Fills the bars in [PlacementFit.fitColor].
  final ui.Color dominantColor;
}

abstract class WallpaperPositionRepository {
  /// Loads and decodes the wall at [url], a web address or a local file path. The decode is capped in size.
  Future<PlacementSource> load(String url);

  /// Renders [placement] at [outputSize] and writes a PNG for the plugin to set.
  Future<File> render(PlacementSource source, WallpaperPlacement placement, ui.Size outputSize);

  /// Deletes a file made by [render].
  Future<void> discard(File file);
}
