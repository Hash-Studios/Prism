import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/domain/repositories/trending_repository.dart';
import 'package:injectable/injectable.dart';

export 'package:Prism/features/trending/domain/repositories/trending_repository.dart' show TrendingFetch;

@lazySingleton
class FetchTrendingUseCase {
  FetchTrendingUseCase(this._repository);

  final TrendingRepository _repository;

  Future<TrendingFetch> call(NoParams params) => _repository.fetch();

  Future<List<PrismWallpaper>> readCached() => _repository.readCached();
}
