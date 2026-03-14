import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/informatics/dataManager.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FetchWallpaperViewsUsecase {
  const FetchWallpaperViewsUsecase();

  Future<Result<String>> call(String wallId) async {
    try {
      final views = await getViews(wallId.toUpperCase());
      return Result.success(views);
    } catch (e) {
      return Result.error(ServerFailure('Failed to fetch views: $e'));
    }
  }
}

@lazySingleton
class UpdateWallpaperViewsUsecase {
  const UpdateWallpaperViewsUsecase();

  Future<Result<void>> call(String wallId) async {
    try {
      await updateViews(wallId.toUpperCase());
      return Result.success(null);
    } catch (e) {
      return Result.error(ServerFailure('Failed to update views: $e'));
    }
  }
}
