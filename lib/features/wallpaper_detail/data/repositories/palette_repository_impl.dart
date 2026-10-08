import 'dart:io';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/palette_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/repositories/palette_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as p;

@LazySingleton(as: PaletteRepository)
class PaletteRepositoryImpl implements PaletteRepository {
  @override
  Future<Result<PaletteEntity>> generatePalette(String imageUrl) async {
    final isLocalFile = p.isAbsolute(imageUrl);
    if (!isValidNetworkUrl(imageUrl) && !isLocalFile) {
      return Result.error(const ValidationFailure('Image url is not a valid network URI'));
    }

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        ResizeImage(
          isLocalFile ? FileImage(File(imageUrl)) : CachedNetworkImageProvider(imageUrl),
          height: 64,
          width: 64,
        ),
      );

      final dominant = generator.dominantColor?.color.toARGB32() ?? 0xffe57697;
      final colors = generator.paletteColors.map((color) => color.color.toARGB32()).toList();
      return Result.success(
        PaletteEntity(imageUrl: imageUrl, dominantColorValue: dominant, paletteColorValues: colors),
      );
    } catch (error) {
      return Result.error(NetworkFailure('Failed to build palette: $error'));
    }
  }
}
