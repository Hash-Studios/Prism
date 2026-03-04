import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';

extension WallhavenLegacyThumbsX on WallPaper {
  String get originalThumb => thumbs?['original']?.toString() ?? path?.toString() ?? url?.toString() ?? '';
  String get smallThumb => thumbs?['small']?.toString() ?? originalThumb;
}

extension PexelsLegacySrcX on WallPaperP {
  String get originalSrc => src?['original']?.toString() ?? url?.toString() ?? '';
  String get mediumSrc => src?['medium']?.toString() ?? originalSrc;
  String get smallSrc => src?['small']?.toString() ?? mediumSrc;
}
