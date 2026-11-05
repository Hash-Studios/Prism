import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:Prism/features/watch_set/domain/smart_watch_crop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('without a subject a portrait source is centred at full width', () {
    final CropSpec crop = smartWatchCrop(sourceWidth: 1080, sourceHeight: 1920, format: WatchFormat.apple46);
    expect(crop.preset, CropPreset.watch);
    expect(crop.rect, const PixelRect(0, 316, 1080, 1288));
  });

  test('without a subject a landscape source is centred at full height', () {
    final CropSpec crop = smartWatchCrop(sourceWidth: 2560, sourceHeight: 1600, format: WatchFormat.pixelWatch);
    expect(crop.rect, const PixelRect(480, 0, 1600, 1600));
  });

  test('a subject near the top clamps the frame to the top edge', () {
    final CropSpec crop = smartWatchCrop(
      sourceWidth: 1080,
      sourceHeight: 1920,
      format: WatchFormat.apple46,
      subject: const PixelRect(400, 100, 200, 200),
    );
    expect(crop.rect, const PixelRect(0, 0, 1080, 1288));
  });

  test('a subject at the middle right clamps the frame to the right edge', () {
    final CropSpec crop = smartWatchCrop(
      sourceWidth: 2560,
      sourceHeight: 1600,
      format: WatchFormat.pixelWatch,
      subject: const PixelRect(2000, 600, 300, 300),
    );
    expect(crop.rect, const PixelRect(960, 0, 1600, 1600));
  });

  test('a subject centred with room to spare centres the frame on it', () {
    final CropSpec crop = smartWatchCrop(
      sourceWidth: 2560,
      sourceHeight: 1600,
      format: WatchFormat.pixelWatch,
      subject: const PixelRect(1000, 700, 200, 200),
    );
    expect(crop.rect, const PixelRect(300, 0, 1600, 1600));
  });

  test('the smart crop is not an adjusted crop', () {
    final CropSpec crop = smartWatchCrop(sourceWidth: 1080, sourceHeight: 1920, format: WatchFormat.apple46);
    expect(crop.adjusted, isFalse);
  });

  test('the output keeps the watch aspect', () {
    final CropSpec crop = smartWatchCrop(sourceWidth: 1080, sourceHeight: 1920, format: WatchFormat.apple46);
    expect(crop.outputWidth / crop.outputHeight, closeTo(WatchFormat.apple46.aspect, 0.01));
  });

  test('scaledTo keeps the crop on the larger source', () {
    final CropSpec crop = smartWatchCrop(sourceWidth: 1000, sourceHeight: 2000, format: WatchFormat.pixelWatch);
    expect(crop.rect, const PixelRect(0, 500, 1000, 1000));
    final CropSpec scaled = crop.scaledTo(sourceWidth: 2000, sourceHeight: 4000);
    expect(scaled.sourceWidth, 2000);
    expect(scaled.rect, const PixelRect(0, 1000, 2000, 2000));
    expect(scaled.preset, CropPreset.watch);
  });

  test('scaledTo keeps a moved crop moved', () {
    final CropSpec crop = smartWatchCrop(
      sourceWidth: 1000,
      sourceHeight: 2000,
      format: WatchFormat.pixelWatch,
    ).moved(0, -200);
    expect(crop.rect, const PixelRect(0, 300, 1000, 1000));
    final CropSpec scaled = crop.scaledTo(sourceWidth: 2000, sourceHeight: 4000);
    expect(scaled.rect, const PixelRect(0, 600, 2000, 2000));
    expect(scaled.adjusted, isTrue);
  });

  test('withPresetAround centres a watch frame on the given point', () {
    final CropSpec whole = CropSpec.initial(
      sourceWidth: 1000,
      sourceHeight: 1000,
      phoneAspect: 9 / 16,
      watchAspect: 0.5,
    );
    final CropSpec crop = whole.withPresetAround(CropPreset.watch, 100, 500);
    expect(crop.rect, const PixelRect(0, 0, 500, 1000));
  });
}
