import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color, Offset, Paint, Rect;

import 'package:Prism/core/cache/prism_image_cache.dart';
// ignore: depend_on_referenced_packages
import 'package:file/file.dart' as fs;
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

const List<(Color, Color)> _palette = <(Color, Color)>[
  (Color(0xFFFF8A65), Color(0xFF7B1FA2)),
  (Color(0xFF4FC3F7), Color(0xFF1A237E)),
  (Color(0xFF81C784), Color(0xFF004D40)),
  (Color(0xFFFFD54F), Color(0xFFE64A19)),
  (Color(0xFFF48FB1), Color(0xFF4A148C)),
  (Color(0xFF90A4AE), Color(0xFF263238)),
  (Color(0xFFA5D6A7), Color(0xFF1565C0)),
  (Color(0xFFCE93D8), Color(0xFF283593)),
];

/// A wallpaper cache that answers every url with a gradient PNG, so grids show colour instead of skeletons.
class QaImages extends Fake implements BaseCacheManager {
  QaImages._(this._files);

  final List<fs.File> _files;

  static List<fs.File>? _generated;

  static Future<void> install(WidgetTester tester) async {
    _generated ??= await tester.runAsync(_generate);
    PrismImageCache.testOverride = QaImages._(_generated!);
  }

  static void uninstall() => PrismImageCache.testOverride = null;

  static Future<List<fs.File>> _generate() async {
    final MemoryFileSystem memory = MemoryFileSystem();
    final List<fs.File> files = <fs.File>[];
    for (final (int i, (Color, Color) colors) in _palette.indexed) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 270, 480),
        Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(270, 480), <Color>[colors.$1, colors.$2]),
      );
      final ui.Image image = await recorder.endRecording().toImage(270, 480);
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final fs.File file = memory.file('/wall_$i.png');
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      files.add(file);
    }
    return files;
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    final fs.File file = _files[url.hashCode.abs() % _files.length];
    return Stream<FileResponse>.value(
      FileInfo(file, FileSource.Cache, DateTime.now().add(const Duration(days: 1)), url),
    );
  }
}
