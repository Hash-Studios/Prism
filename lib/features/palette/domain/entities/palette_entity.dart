class PaletteEntity {
  const PaletteEntity({required this.imageUrl, required this.dominantColorValue, required this.paletteColorValues});

  final String imageUrl;
  final int dominantColorValue;
  final List<int> paletteColorValues;

  static const PaletteEntity empty = PaletteEntity(
    imageUrl: '',
    dominantColorValue: 0xffe57697,
    paletteColorValues: <int>[],
  );
}
