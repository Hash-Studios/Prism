import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/draw/domain/entities/draw_entity.dart';

abstract class DrawRepository {
  /// This week's draw. A missing doc means nobody bought a ticket yet: an open draw with zero tickets.
  Future<Result<DrawEntity>> fetchCurrent(String weekKey);

  /// The most recent settled draw, or null when none settled yet.
  Future<Result<DrawEntity?>> fetchLastSettled();

  /// How many tickets [uid] holds in [weekKey]'s draw.
  Future<Result<int>> fetchMyTickets(String weekKey, String uid);
}
