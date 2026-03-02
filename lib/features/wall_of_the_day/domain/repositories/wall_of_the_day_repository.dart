import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wall_of_the_day_entity.dart';

abstract class WallOfTheDayRepository {
  Future<Result<WallOfTheDayEntity?>> fetchToday();
}
