import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/domain/repositories/trending_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FetchTrendingUseCase implements UseCase<List<PrismWallpaper>, NoParams> {
  FetchTrendingUseCase(this._repository);

  final TrendingRepository _repository;

  @override
  Future<Result<List<PrismWallpaper>>> call(NoParams params) => _repository.fetch();

  Future<List<PrismWallpaper>> readCached() => _repository.readCached();
}
