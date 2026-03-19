import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/palette/domain/entities/palette_entity.dart';
import 'package:Prism/features/palette/domain/repositories/palette_repository.dart';
import 'package:injectable/injectable.dart';

class GeneratePaletteParams {
  const GeneratePaletteParams({required this.imageUrl});

  final String imageUrl;
}

@lazySingleton
class GeneratePaletteUseCase implements UseCase<PaletteEntity, GeneratePaletteParams> {
  GeneratePaletteUseCase(this._repository);

  final PaletteRepository _repository;

  @override
  Future<Result<PaletteEntity>> call(GeneratePaletteParams params) {
    return _repository.generatePalette(params.imageUrl);
  }
}
