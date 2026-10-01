import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/features/wallpaper_detail/data/repositories/palette_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repository = PaletteRepositoryImpl();

  test('generates a palette from a downloaded image file', () async {
    final directory = await Directory.systemTemp.createTemp('palette-test-');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/download.png');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffff0000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(10, 10);
    final png = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    await image.writeAsBytes(png!.buffer.asUint8List());
    picture.dispose();
    uiImage.dispose();

    final result = await repository.generatePalette(image.path);

    expect(result.isSuccess, isTrue, reason: result.failure?.message);
    expect(result.data?.imageUrl, image.path);
    expect(result.data?.dominantColorValue, 0xfff80000);
    expect(result.data?.paletteColorValues, contains(0xfff80000));
  });

  test('a deleted downloaded image returns a failure instead of throwing', () async {
    final directory = await Directory.systemTemp.createTemp('palette-test-');
    addTearDown(() => directory.delete(recursive: true));
    final image = File('${directory.path}/deleted.png');

    final result = await repository.generatePalette(image.path);

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<NetworkFailure>());
    expect(result.failure?.message, startsWith('Failed to build palette:'));
  });

  test('rejects relative paths instead of treating them as local files', () async {
    final result = await repository.generatePalette('download.png');

    expect(result.failure, isA<ValidationFailure>());
  });
}
