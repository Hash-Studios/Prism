import 'dart:math' as math;

import 'package:Prism/core/coins/economy_config.dart';
import 'package:equatable/equatable.dart';

/// One wall of a Drop, as the planner snapshotted it. It has no full url: that comes with the unlock.
class DropWall extends Equatable {
  const DropWall({
    required this.id,
    required this.title,
    required this.thumb,
    required this.resolution,
    required this.by,
    required this.seriesId,
  });

  final String id;
  final String title;
  final String thumb;
  final String resolution;
  final String by;
  final String seriesId;

  @override
  List<Object?> get props => [id, title, thumb, resolution, by, seriesId];
}

class DropEntity extends Equatable {
  const DropEntity({
    required this.weekKey,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.priceWall,
    required this.pricePack,
    required this.count,
    required this.walls,
  });

  final String weekKey;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final int priceWall;
  final int pricePack;
  final int count;
  final List<DropWall> walls;

  bool isLiveAt(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);

  int wallPrice({required bool isPro}) => proPrice(priceWall, isPro);

  /// The server price of the pack: every wall left at the wall price, capped by the pack price, then the Pro half.
  /// Zero when nothing is left to buy.
  int packPrice({required int remaining, required bool isPro}) {
    if (remaining <= 0) return 0;
    return proPrice(math.min(pricePack, remaining * priceWall), isPro);
  }

  /// "Ends in 3d 4h", down to minutes in the last hour.
  String endsInLabel(DateTime now) {
    final Duration left = endsAt.difference(now);
    if (left <= Duration.zero) return 'Ended';
    if (left.inDays > 0) return 'Ends in ${left.inDays}d ${left.inHours % 24}h';
    if (left.inHours > 0) return 'Ends in ${left.inHours}h ${left.inMinutes % 60}m';
    return 'Ends in ${math.max(1, left.inMinutes)}m';
  }

  @override
  List<Object?> get props => [weekKey, title, startsAt, endsAt, priceWall, pricePack, count, walls];
}
