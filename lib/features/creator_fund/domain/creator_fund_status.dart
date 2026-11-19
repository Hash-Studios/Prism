enum CreatorFundReason { noActivity, fewUsers, smallShare, moderation, team }

sealed class CreatorFundStatus {
  const CreatorFundStatus({required this.week});
  final String week;
}

final class CreatorFundOff extends CreatorFundStatus {
  const CreatorFundOff({required super.week});

  @override
  bool operator ==(Object other) => other is CreatorFundOff && other.week == week;

  @override
  int get hashCode => Object.hash(runtimeType, week);
}

final class CreatorFundPending extends CreatorFundStatus {
  const CreatorFundPending({required super.week});

  @override
  bool operator ==(Object other) => other is CreatorFundPending && other.week == week;

  @override
  int get hashCode => Object.hash(runtimeType, week);
}

final class CreatorFundPaid extends CreatorFundStatus {
  const CreatorFundPaid({required super.week, required this.coins, required this.shareBps});
  final int coins;
  final int shareBps;

  @override
  bool operator ==(Object other) =>
      other is CreatorFundPaid && other.week == week && other.coins == coins && other.shareBps == shareBps;

  @override
  int get hashCode => Object.hash(runtimeType, week, coins, shareBps);
}

final class CreatorFundNotQualified extends CreatorFundStatus {
  const CreatorFundNotQualified({
    required super.week,
    required this.reason,
    required this.distinctUsers,
    required this.minDistinctUsers,
    required this.minPayout,
    this.shareBps,
  });
  final CreatorFundReason reason;
  final int distinctUsers;
  final int minDistinctUsers;
  final int minPayout;
  final int? shareBps;

  @override
  bool operator ==(Object other) =>
      other is CreatorFundNotQualified &&
      other.week == week &&
      other.reason == reason &&
      other.distinctUsers == distinctUsers &&
      other.minDistinctUsers == minDistinctUsers &&
      other.minPayout == minPayout &&
      other.shareBps == shareBps;

  @override
  int get hashCode => Object.hash(runtimeType, week, reason, distinctUsers, minDistinctUsers, minPayout, shareBps);
}
