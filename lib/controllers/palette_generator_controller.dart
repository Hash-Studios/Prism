import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/palette_generator_service.dart';

class PaletteGeneratorController extends ChangeNotifier {
  final PaletteGeneratorService _paletteGeneratorService =
      locator<PaletteGeneratorService>();

  PaletteGeneratorController(String url) {
    getWallpaperPalette(url);
  }

  PaletteGenerator? paletteGenerator;

  Future<PaletteGenerator?> getWallpaperPalette(String url) async {
    paletteGenerator = await _paletteGeneratorService.getWallpaperPalette(url);
    notifyListeners();
    return paletteGenerator;
  }
}
