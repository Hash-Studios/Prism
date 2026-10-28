import 'package:Prism/features/live_wallpaper/data/texture_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double phone = 1080 / 2400;

  test('a wide photo is cropped to the screen shape and capped', () {
    final TextureGeometry geometry = TextureGeometry.compute(
      sourceWidth: 6000,
      sourceHeight: 4000,
      screenAspectRatio: phone,
    );
    expect(geometry.cropHeight, 4000);
    expect(geometry.cropWidth, closeTo(1800, 0.01));
    expect(geometry.cropLeft, closeTo(2100, 0.01));
    expect(geometry.cropTop, 0);
    expect(geometry.outputHeight, lessThanOrEqualTo(TextureGeometry.maxOutputHeight));
    expect(geometry.outputWidth / geometry.outputHeight, closeTo(phone, 0.002));
  });

  test('a tall photo keeps its width and crops the height', () {
    final TextureGeometry geometry = TextureGeometry.compute(
      sourceWidth: 1000,
      sourceHeight: 3000,
      screenAspectRatio: phone,
    );
    expect(geometry.cropWidth, 1000);
    expect(geometry.cropHeight, closeTo(2222.22, 0.01));
    expect(geometry.cropTop, closeTo(388.89, 0.01));
    expect(geometry.cropLeft, 0);
  });

  test('a small photo is never upscaled', () {
    final TextureGeometry geometry = TextureGeometry.compute(
      sourceWidth: 400,
      sourceHeight: 900,
      screenAspectRatio: phone,
    );
    expect(geometry.outputHeight, lessThanOrEqualTo(900));
    expect(geometry.scale, lessThanOrEqualTo(1.0));
  });

  test('output stays inside the renderer texture limits', () {
    for (final double aspect in <double>[0.3, 0.45, 0.56, 1.0, 1.6]) {
      final TextureGeometry geometry = TextureGeometry.compute(
        sourceWidth: 8000,
        sourceHeight: 8000,
        screenAspectRatio: aspect,
      );
      expect(geometry.outputWidth, lessThanOrEqualTo(4096));
      expect(geometry.outputHeight, lessThanOrEqualTo(4096));
      expect(geometry.outputWidth * geometry.outputHeight, lessThanOrEqualTo(4 * 1024 * 1024));
    }
  });

  test('a bad aspect ratio falls back to a phone shape', () {
    final TextureGeometry geometry = TextureGeometry.compute(
      sourceWidth: 2000,
      sourceHeight: 2000,
      screenAspectRatio: double.nan,
    );
    expect(geometry.outputWidth, lessThan(geometry.outputHeight));
  });

  group('scaledTo', () {
    void expectDepthMapMatchesPhoto({
      required int photoWidth,
      required int photoHeight,
      required int mapWidth,
      required int mapHeight,
    }) {
      final TextureGeometry photo = TextureGeometry.compute(
        sourceWidth: photoWidth,
        sourceHeight: photoHeight,
        screenAspectRatio: 9 / 19.5,
      );
      final TextureGeometry map = photo.scaledTo(
        fromWidth: photoWidth,
        fromHeight: photoHeight,
        toWidth: mapWidth,
        toHeight: mapHeight,
      );
      expect(map.cropLeft / mapWidth, closeTo(photo.cropLeft / photoWidth, 1e-9));
      expect(map.cropTop / mapHeight, closeTo(photo.cropTop / photoHeight, 1e-9));
      expect(map.cropWidth / mapWidth, closeTo(photo.cropWidth / photoWidth, 1e-9));
      expect(map.cropHeight / mapHeight, closeTo(photo.cropHeight / photoHeight, 1e-9));
      expect(map.outputWidth / map.outputHeight, closeTo(photo.outputWidth / photo.outputHeight, 0.01));
      expect(map.outputHeight, lessThanOrEqualTo(map.cropHeight));
    }

    test('a 4000x6000 photo and its 341x512 depth map share the crop', () {
      expectDepthMapMatchesPhoto(photoWidth: 4000, photoHeight: 6000, mapWidth: 341, mapHeight: 512);
    });

    test('a 6000x4000 photo and its 512x341 depth map share the crop', () {
      expectDepthMapMatchesPhoto(photoWidth: 6000, photoHeight: 4000, mapWidth: 512, mapHeight: 341);
    });
  });
}
