abstract interface class FavouriteCountsRepository {
  /// Missing documents in a successful read are zero. Failed reads must throw.
  Future<Map<String, PrismWallpaperStats>> fetch(Set<String> ids);
}

final class PrismWallpaperStats {
  const PrismWallpaperStats({required this.favourites, this.views, this.comments = 0});

  final int favourites;
  final int? views;

  /// Visible comments. The comment callables keep it in the same doc.
  final int comments;

  @override
  bool operator ==(Object other) =>
      other is PrismWallpaperStats &&
      other.favourites == favourites &&
      other.views == views &&
      other.comments == comments;

  @override
  int get hashCode => Object.hash(favourites, views, comments);
}

String? prismStatsId(String raw) {
  final id = raw.trim().toUpperCase();
  return id.length <= 128 && RegExp(r'^[A-Z0-9._-]+$').hasMatch(id) ? id : null;
}
