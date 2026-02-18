import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/palette/domain/entities/palette_entity.dart';
import 'package:Prism/features/palette/domain/repositories/palette_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:palette_generator/palette_generator.dart';

@LazySingleton(as: PaletteRepository)
class PaletteRepositoryImpl implements PaletteRepository {
  @override
  Future<Result<PaletteEntity>> generatePalette(String imageUrl) async {
    if (imageUrl.isEmpty) {
      return Result.error(const ValidationFailure('Image url cannot be empty'));
    }

    try {
      final generator = await PaletteGenerator.fromImageProvider(
        ResizeImage(CachedNetworkImageProvider(imageUrl), height: 10, width: 10),
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
