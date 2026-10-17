import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';

abstract class DropsRepository {
  /// The Drop that is on now, or null between Drops.
  Future<Result<DropEntity?>> fetchLive(DateTime now);

  Future<Result<DropEntity?>> fetchByWeekKey(String weekKey);
}
