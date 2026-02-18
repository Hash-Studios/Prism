enum QuickActionType { followFeed, collections, setups, downloads, unknown }

class QuickActionEntity {
  const QuickActionEntity({required this.type, required this.rawValue});

  final QuickActionType type;
  final String rawValue;
}
