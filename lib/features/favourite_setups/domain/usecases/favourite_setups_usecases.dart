import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/favourite_setups/domain/repositories/favourite_setups_repository.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:injectable/injectable.dart';

class FetchFavouriteSetupsParams {
  const FetchFavouriteSetupsParams({required this.userId});

  final String userId;
}

@lazySingleton
class FetchFavouriteSetupsUseCase implements UseCase<List<SetupEntity>, FetchFavouriteSetupsParams> {
  FetchFavouriteSetupsUseCase(this._repository);

  final FavouriteSetupsRepository _repository;

  @override
  Future<Result<List<SetupEntity>>> call(FetchFavouriteSetupsParams params) {
    return _repository.fetchFavourites(userId: params.userId);
  }
}

class ToggleFavouriteSetupParams {
  const ToggleFavouriteSetupParams({required this.userId, required this.setup});

  final String userId;
  final SetupEntity setup;
}

@lazySingleton
class ToggleFavouriteSetupUseCase implements UseCase<List<SetupEntity>, ToggleFavouriteSetupParams> {
  ToggleFavouriteSetupUseCase(this._repository);

  final FavouriteSetupsRepository _repository;

  @override
  Future<Result<List<SetupEntity>>> call(ToggleFavouriteSetupParams params) {
    return _repository.toggleFavourite(userId: params.userId, setup: params.setup);
  }
}
