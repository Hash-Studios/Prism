import 'dart:typed_data';

import 'package:Prism/core/color/prism_palette.dart';

/// One palette colour and its share of a photo. The shares in a [PhotoQuery] add up to 1.
typedef PaletteShare = ({PrismPaletteColor color, double share});

/// Whether a [PhotoQuery] has labels, and why not when it has none.
enum PhotoLabelsStatus {
  found,

  /// A guest picked the photo, so it never left the phone.
  guest,

  /// The user reached the daily photo search limit.
  capped,

  /// The labels call failed. The search still runs on colour.
  unavailable,
}

/// What Search matches a picked photo by: its main colours, read on the phone, and for a signed-in user what Cloud
/// Vision saw in it.
class PhotoQuery {
  const PhotoQuery({
    required this.preview,
    required this.palette,
    required this.labelsStatus,
    this.labels = const <String>[],
    this.category,
  }) : assert(palette.length > 0 && palette.length <= 3),
       assert(labels.length <= 5);

  /// The downscaled photo without metadata. The search chip shows it.
  final Uint8List preview;

  /// One to three colours, the largest share first.
  final List<PaletteShare> palette;

  /// Up to five Cloud Vision labels, the most certain first.
  final List<String> labels;

  /// The Prism category that the labels map to, or `null` when they map to none.
  final String? category;

  final PhotoLabelsStatus labelsStatus;

  PrismPaletteColor get topColor => palette.first.color;

  /// The query for Wallhaven and Pexels: the top label, or empty for a colour-only search.
  String get topLabel => labels.isEmpty ? '' : labels.first;
}
