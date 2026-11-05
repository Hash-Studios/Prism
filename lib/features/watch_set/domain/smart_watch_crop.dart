import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';

/// The first watch frame: the largest frame of [format]'s aspect in the image, centred on [subject] when there is one,
/// else on the image, then kept inside the image. [subject] is in source pixels.
CropSpec smartWatchCrop({
  required int sourceWidth,
  required int sourceHeight,
  required WatchFormat format,
  PixelRect? subject,
}) {
  final CropSpec whole = CropSpec.initial(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    phoneAspect: 9 / 16,
    watchAspect: format.aspect,
  );
  final double centreX = subject == null ? sourceWidth / 2 : subject.left + subject.width / 2;
  final double centreY = subject == null ? sourceHeight / 2 : subject.top + subject.height / 2;
  return whole.withPresetAround(CropPreset.watch, centreX, centreY);
}
