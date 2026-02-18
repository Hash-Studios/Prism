import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_walls_repository.dart';
import 'package:injectable/injectable.dart';

class FetchFavouriteWallsParams {
  const FetchFavouriteWallsParams({required this.userId});

  final String userId;
}

@lazySingleton
class FetchFavouriteWallsUseCase implements UseCase<List<FavouriteWallEntity>, FetchFavouriteWallsParams> {
  FetchFavouriteWallsUseCase(this._repository);

  final FavouriteWallsRepository _repository;

  @override
  Future<Result<List<FavouriteWallEntity>>> call(FetchFavouriteWallsParams params) {
    return _repository.fetchFavourites(userId: params.userId);
  }
}

class ToggleFavouriteWallParams {
  const ToggleFavouriteWallParams({required this.userId, required this.wall, required this.currentlyFavourited});

  final String userId;
  final FavouriteWallEntity wall;
  final bool currentlyFavourited;
}

@lazySingleton
class ToggleFavouriteWallUseCase implements UseCase<bool, ToggleFavouriteWallParams> {
  ToggleFavouriteWallUseCase(this._repository);

  final FavouriteWallsRepository _repository;

  @override
  Future<Result<bool>> call(ToggleFavouriteWallParams params) {
    return _repository.toggleFavourite(
      userId: params.userId,
      wall: params.wall,
      currentlyFavourited: params.currentlyFavourited,
    );
  }
}

class RemoveFavouriteWallParams {
  const RemoveFavouriteWallParams({required this.userId, required this.wallId});

  final String userId;
  final String wallId;
}

@lazySingleton
class RemoveFavouriteWallUseCase implements UseCase<bool, RemoveFavouriteWallParams> {
  RemoveFavouriteWallUseCase(this._repository);

  final FavouriteWallsRepository _repository;

  @override
  Future<Result<bool>> call(RemoveFavouriteWallParams params) {
    return _repository.removeFavourite(userId: params.userId, wallId: params.wallId);
  }
}

class ClearFavouriteWallsParams {
  const ClearFavouriteWallsParams({required this.userId, required this.wallIds});

  final String userId;
  final List<String> wallIds;
}

@lazySingleton
class ClearFavouriteWallsUseCase implements UseCase<bool, ClearFavouriteWallsParams> {
  ClearFavouriteWallsUseCase(this._repository);

  final FavouriteWallsRepository _repository;

  @override
  Future<Result<bool>> call(ClearFavouriteWallsParams params) {
    return _repository.clearAll(userId: params.userId, wallIds: params.wallIds);
  }
}
