abstract interface class FavouriteCountsRepository {
  /// Missing documents in a successful read are zero. Failed reads must throw.
  Future<Map<String, int>> fetch(Set<String> ids);
}

String? prismStatsId(String raw) {
  final id = raw.trim().toUpperCase();
  return id.length <= 128 && RegExp(r'^[A-Z0-9._-]+$').hasMatch(id) ? id : null;
}
