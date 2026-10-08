import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/features/wallpaper_position/data/repositories/wallpaper_position_repository_impl.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  final WallpaperPositionRepositoryImpl repository = WallpaperPositionRepositoryImpl();
  const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    temp = Directory.systemTemp.createTempSync('position_repo_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => temp.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(pathChannel, null);
    temp.deleteSync(recursive: true);
  });

  Future<File> writePng(int width, int height, Color color) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
    final ui.Image image = await recorder.endRecording().toImage(width, height);
    final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    return File('${temp.path}/source.png')..writeAsBytesSync(data.buffer.asUint8List());
  }

  testWidgets('loads a local wall and reads its dominant colour', (tester) async {
    await tester.runAsync(() async {
      final File file = await writePng(300, 300, const Color(0xFF0000FF));

      final PlacementSource source = await repository.load(file.path);

      expect((source.image.width, source.image.height), (300, 300));
      expect(source.dominantColor.b, greaterThan(0.9));
      source.image.dispose();
    });
  });

  testWidgets('a missing local file fails to load', (tester) async {
    await tester.runAsync(() async {
      await expectLater(repository.load('${temp.path}/missing.png'), throwsA(isA<FileSystemException>()));
    });
  });

  testWidgets('render writes a PNG of the output size under prism_edit and discard removes it', (tester) async {
    await tester.runAsync(() async {
      final File file = await writePng(60, 120, const Color(0xFFFF0000));
      final PlacementSource source = await repository.load(file.path);

      final File out = await repository.render(source, const WallpaperPlacement(dim: 0.3), const ui.Size(45, 90));

      expect(out.path, contains('${Platform.pathSeparator}prism_edit${Platform.pathSeparator}'));
      expect(out.path, endsWith('placement.png'));
      final ui.Codec codec = await ui.instantiateImageCodec(out.readAsBytesSync());
      final ui.Image rendered = (await codec.getNextFrame()).image;
      expect((rendered.width, rendered.height), (45, 90));

      await repository.discard(out);

      expect(out.existsSync(), isFalse);
      expect(out.parent.existsSync(), isFalse);
      source.image.dispose();
    });
  });

  testWidgets('discard ignores a file that is already gone', (tester) async {
    await tester.runAsync(() async {
      await repository.discard(File('${temp.path}/gone/placement.png'));
    });
  });
}
