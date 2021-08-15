import 'package:Prism/logger/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteNotifier extends ChangeNotifier {
  late PaletteGenerator paletteGenerator;
  bool isLoading = true;

  Future<PaletteGenerator> updatePaletteGenerator(String link) async {
    logger.d("Palette Generator called");
    isLoading = true;
    notifyListeners();
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      ResizeImage(
        CachedNetworkImageProvider(link),
        height: 10,
        width: 10,
      ),
    );
    isLoading = false;
    notifyListeners();
    return paletteGenerator;
  }
}
