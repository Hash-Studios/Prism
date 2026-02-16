class FavouriteWallEntity {
  const FavouriteWallEntity({
    required this.id,
    required this.provider,
    required this.payload,
  });

  final String id;
  final String provider;
  final Map<String, dynamic> payload;
}
