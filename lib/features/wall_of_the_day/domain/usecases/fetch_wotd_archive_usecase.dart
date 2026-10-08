import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:Prism/features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FetchWotdArchiveUseCase implements UseCase<List<WotdPastPick>, NoParams> {
  FetchWotdArchiveUseCase(this._repository);

  final WallOfTheDayRepository _repository;

  @override
  Future<Result<List<WotdPastPick>>> call(NoParams params) => _repository.fetchRecent();
}
