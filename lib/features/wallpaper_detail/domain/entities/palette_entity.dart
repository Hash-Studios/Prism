class PaletteEntity {
  const PaletteEntity({required this.imageUrl, required this.dominantColorValue, required this.paletteColorValues});

  final String imageUrl;
  final int dominantColorValue;
  final List<int> paletteColorValues;
}
