abstract interface class FavouriteCountsRepository {
  /// Missing documents in a successful read are zero. Failed reads must throw.
  Future<Map<String, PrismWallpaperStats>> fetch(Set<String> ids);
}

final class PrismWallpaperStats {
  const PrismWallpaperStats({required this.favourites, this.views});

  final int favourites;
  final int? views;

  @override
  bool operator ==(Object other) =>
      other is PrismWallpaperStats && other.favourites == favourites && other.views == views;

  @override
  int get hashCode => Object.hash(favourites, views);
}

String? prismStatsId(String raw) {
  final id = raw.trim().toUpperCase();
  return id.length <= 128 && RegExp(r'^[A-Z0-9._-]+$').hasMatch(id) ? id : null;
}
