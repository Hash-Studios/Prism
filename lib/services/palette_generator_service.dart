// import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteGeneratorService {
  // List<PaletteGenerator?> collectionPaletteGeneratorList =
  //     List<PaletteGenerator?>.filled(30, null, growable: true);
  late PaletteGenerator paletteGenerator;

  // Map<String, PaletteGenerator> wallpaperPalettes = {};

  // Color getTextColor(int index) {
  //   return (collectionPaletteGeneratorList[index]?.colors.toList()[0] ??
  //                   Colors.black)
  //               .computeLuminance() <
  //           0.3
  //       ? Colors.white
  //       : Colors.black;
  // }

  // Future<void> getCollectionColorPalette(int index) async {
  //   final WallpaperNotifier _wallpaperNotifier = locator<WallpaperNotifier>();
  //   final collection = _wallpaperNotifier.collections?[index] ??
  //       Collection(name: "", wallpapers: []);
  //   collectionPaletteGeneratorList[index] =
  //       await PaletteGenerator.fromImageProvider(
  //     ResizeImage(
  //       CachedNetworkImageProvider(
  //         collection.wallpapers[0].thumbnail ?? collection.wallpapers[0].url,
  //       ),
  //       height: 100,
  //       width: 100,
  //     ),
  //   );
  // }

  // Future<void> getWallpaperColorPalette(String url) async {
  //   wallpaperPalettes[url] = await PaletteGenerator.fromImageProvider(
  //     ResizeImage(
  //       CachedNetworkImageProvider(
  //         url,
  //       ),
  //       height: 100,
  //       width: 100,
  //     ),
  //   );
  // }

  // Future<void> getLocalWallpaperColorPalette(File file) async {
  //   wallpaperPalettes[file.path] = await PaletteGenerator.fromImageProvider(
  //     ResizeImage(
  //       FileImage(file),
  //       height: 100,
  //       width: 100,
  //     ),
  //   );
  // }

  Future<PaletteGenerator> getWallpaperPalette(String url) async {
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      ResizeImage(
        CachedNetworkImageProvider(
          url,
        ),
        height: 100,
        width: 100,
      ),
    );
    return paletteGenerator;
  }
}
