import 'package:Prism/core/utils/result.dart';

import 'package:Prism/features/palette/domain/entities/palette_entity.dart';

abstract class PaletteRepository {
  Future<Result<PaletteEntity>> generatePalette(String imageUrl);
}
