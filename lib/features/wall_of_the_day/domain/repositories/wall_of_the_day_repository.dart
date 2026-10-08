import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';

abstract class WallOfTheDayRepository {
  Future<Result<WallOfTheDayEntity?>> fetchToday();

  /// The latest picks, newest first. Walls that are gone, hidden or not reviewed are left out.
  Future<Result<List<WotdPastPick>>> fetchRecent({int limit = 30});
}
