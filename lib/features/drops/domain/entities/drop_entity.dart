import 'dart:math' as math;

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/l10n/l10n.dart';
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

/// Where a Drop is in its week. [lastCall] is the final [DropEntity.lastCallWindow] before it ends.
enum DropPhase { live, lastCall, ended }

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
    this.collectors = 0,
  });

  static const Duration lastCallWindow = Duration(hours: 24);

  final String weekKey;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final int priceWall;
  final int pricePack;
  final int count;
  final List<DropWall> walls;

  /// Users who unlocked at least one wall of this Drop. The server counts each user once.
  final int collectors;

  bool isLiveAt(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);

  DropPhase phaseAt(DateTime now) {
    if (!isLiveAt(now)) return DropPhase.ended;
    return endsAt.difference(now) <= lastCallWindow ? DropPhase.lastCall : DropPhase.live;
  }

  String displayTitle(AppLocalizations l10n) => title.trim().isEmpty ? l10n.economyWeeklyDrop : title;

  int wallPrice({required bool isPro}) => proPrice(priceWall, isPro);

  /// The server price of the pack: every wall left at the wall price, capped by the pack price, then the Pro half.
  /// Zero when nothing is left to buy.
  int packPrice({required int remaining, required bool isPro}) {
    if (remaining <= 0) return 0;
    return proPrice(math.min(pricePack, remaining * priceWall), isPro);
  }

  /// "Ends in 3d 4h", down to minutes in the last hour.
  String endsInLabel(AppLocalizations l10n, DateTime now) {
    final Duration left = endsAt.difference(now);
    if (left <= Duration.zero) return l10n.economyDropEnded;
    if (left.inDays > 0) return l10n.economyDropEndsInDaysHours(left.inDays, left.inHours % 24);
    if (left.inHours > 0) return l10n.economyDropEndsInHoursMinutes(left.inHours, left.inMinutes % 60);
    return l10n.economyDropEndsInMinutes(math.max(1, left.inMinutes));
  }

  @override
  List<Object?> get props => [weekKey, title, startsAt, endsAt, priceWall, pricePack, count, walls, collectors];
}
