import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/domain/repositories/favourite_setups_repository.dart';
import 'package:injectable/injectable.dart';

class FetchFavouriteSetupsParams {
  const FetchFavouriteSetupsParams({required this.userId});

  final String userId;
}

@lazySingleton
class FetchFavouriteSetupsUseCase implements UseCase<List<FavouriteSetupEntity>, FetchFavouriteSetupsParams> {
  FetchFavouriteSetupsUseCase(this._repository);

  final FavouriteSetupsRepository _repository;

  @override
  Future<Result<List<FavouriteSetupEntity>>> call(FetchFavouriteSetupsParams params) {
    return _repository.fetchFavourites(userId: params.userId);
  }
}

class ToggleFavouriteSetupParams {
  const ToggleFavouriteSetupParams({required this.userId, required this.setup});

  final String userId;
  final FavouriteSetupEntity setup;
}

@lazySingleton
class ToggleFavouriteSetupUseCase implements UseCase<List<FavouriteSetupEntity>, ToggleFavouriteSetupParams> {
  ToggleFavouriteSetupUseCase(this._repository);

  final FavouriteSetupsRepository _repository;

  @override
  Future<Result<List<FavouriteSetupEntity>>> call(ToggleFavouriteSetupParams params) {
    return _repository.toggleFavourite(userId: params.userId, setup: params.setup);
  }
}

class RemoveFavouriteSetupParams {
  const RemoveFavouriteSetupParams({required this.userId, required this.setupId});

  final String userId;
  final String setupId;
}

@lazySingleton
class RemoveFavouriteSetupUseCase implements UseCase<List<FavouriteSetupEntity>, RemoveFavouriteSetupParams> {
  RemoveFavouriteSetupUseCase(this._repository);

  final FavouriteSetupsRepository _repository;

  @override
  Future<Result<List<FavouriteSetupEntity>>> call(RemoveFavouriteSetupParams params) {
    return _repository.removeFavourite(userId: params.userId, setupId: params.setupId);
  }
}

class ClearFavouriteSetupsParams {
  const ClearFavouriteSetupsParams({required this.userId});

  final String userId;
}

@lazySingleton
class ClearFavouriteSetupsUseCase implements UseCase<List<FavouriteSetupEntity>, ClearFavouriteSetupsParams> {
  ClearFavouriteSetupsUseCase(this._repository);

  final FavouriteSetupsRepository _repository;

  @override
  Future<Result<List<FavouriteSetupEntity>>> call(ClearFavouriteSetupsParams params) {
    return _repository.clearAll(userId: params.userId);
  }
}
