import 'dart:io';

import 'package:Prism/features/live_wallpaper/data/repositories/live_wallpaper_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LiveWallpaperRepositoryImpl repository = LiveWallpaperRepositoryImpl();
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('live_wallpaper_test'));
  tearDown(() => directory.deleteSync(recursive: true));

  test('frame rates are 30 by default and 15 with battery saver', () {
    expect(LiveWallpaperRepositoryImpl.defaultFrameRate, 30);
    expect(LiveWallpaperRepositoryImpl.batterySaverFrameRate, 15);
  });

  test('a missing video is reported', () async {
    expect(await repository.validateVideo('${directory.path}/missing.mp4'), contains('Pick it again'));
  });

  test('a small video is accepted', () async {
    final File file = File('${directory.path}/small.mp4')..writeAsBytesSync(<int>[0, 1, 2]);
    expect(await repository.validateVideo(file.path), isNull);
  });

  test('a video over 256 MB is refused with a clear error', () async {
    final File file = File('${directory.path}/huge.mp4');
    final RandomAccessFile handle = file.openSync(mode: FileMode.write)
      ..setPositionSync(LiveWallpaperRepositoryImpl.maxVideoBytes)
      ..writeByteSync(0);
    handle.closeSync();
    expect(await repository.validateVideo(file.path), 'That video is larger than 256 MB. Pick a shorter clip.');
  });
}
