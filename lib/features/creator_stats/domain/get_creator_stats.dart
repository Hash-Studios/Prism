import 'package:Prism/features/creator_stats/domain/creator_stats.dart';
import 'package:injectable/injectable.dart';

@injectable
class GetCreatorStats {
  const GetCreatorStats(this._repository);
  final CreatorStatsRepository _repository;
  Future<CreatorStats> call() => _repository.fetch();
}
