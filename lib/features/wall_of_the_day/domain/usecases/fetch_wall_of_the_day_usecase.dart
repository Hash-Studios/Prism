import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FetchWallOfTheDayUseCase implements UseCase<WallOfTheDayEntity?, NoParams> {
  FetchWallOfTheDayUseCase(this._repository);

  final WallOfTheDayRepository _repository;

  @override
  Future<Result<WallOfTheDayEntity?>> call(NoParams params) => _repository.fetchToday();
}
