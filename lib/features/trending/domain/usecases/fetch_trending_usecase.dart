import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/domain/entities/trending_range.dart';
import 'package:Prism/features/trending/domain/repositories/trending_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FetchTrendingUseCase implements UseCase<List<PrismWallpaper>, TrendingRange> {
  FetchTrendingUseCase(this._repository);

  final TrendingRepository _repository;

  @override
  Future<Result<List<PrismWallpaper>>> call(TrendingRange params) => _repository.fetch(params);
}
