/// Smallest short side, in pixels, that still looks sharp as a phone wallpaper.
const int recommendedShortSide = 1080;

enum UploadQualityWarning { lowResolution, landscape }

/// Soft warnings for a picked image. They never block an upload.
List<UploadQualityWarning> uploadQualityWarnings({required int width, required int height}) => <UploadQualityWarning>[
  if (width < height ? width < recommendedShortSide : height < recommendedShortSide) UploadQualityWarning.lowResolution,
  if (width > height) UploadQualityWarning.landscape,
];

String uploadQualityWarningText(
  UploadQualityWarning warning, {
  required int width,
  required int height,
}) => switch (warning) {
  UploadQualityWarning.lowResolution =>
    'This image is ${width}x$height. It can look soft on a phone. $recommendedShortSide px on the short side is best.',
  UploadQualityWarning.landscape => 'This image is wide. Phone wallpapers look best in portrait.',
};
