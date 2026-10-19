import 'package:Prism/l10n/l10n.dart';

/// Smallest short side, in pixels, that still looks sharp as a phone wallpaper.
const int recommendedShortSide = 1080;

enum UploadQualityWarning { lowResolution, landscape }

/// Soft warnings for a picked image. They never block an upload.
List<UploadQualityWarning> uploadQualityWarnings({required int width, required int height}) => <UploadQualityWarning>[
  if (width < height ? width < recommendedShortSide : height < recommendedShortSide) UploadQualityWarning.lowResolution,
  if (width > height) UploadQualityWarning.landscape,
];

String uploadQualityWarningText(
  AppLocalizations l10n, {
  required UploadQualityWarning warning,
  required int width,
  required int height,
}) => switch (warning) {
  UploadQualityWarning.lowResolution => l10n.wallpaperUploadQualityLowResolution(width, height, recommendedShortSide),
  UploadQualityWarning.landscape => l10n.wallpaperUploadQualityLandscape,
};
