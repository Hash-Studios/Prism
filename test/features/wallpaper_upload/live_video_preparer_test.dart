import 'dart:io';

import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/features/wallpaper_upload/biz/live_upload_limits.dart';
import 'package:Prism/features/wallpaper_upload/data/live_video_preparer.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMedia extends PrismMediaHostApi {
  _FakeMedia(this.outDir, {this.fail = false});

  final Directory outDir;
  final bool fail;
  final List<List<int>> timesCalls = <List<int>>[];
  final List<(int, int)> sizeCalls = <(int, int)>[];
  int _written = 0;

  @override
  Future<List<String>> extractVideoFrames(String path, List<int> timesMs, int maxEdge, int quality) async {
    timesCalls.add(List<int>.of(timesMs));
    sizeCalls.add((maxEdge, quality));
    if (fail) throw PlatformException(code: 'extract_failed');
    final List<String> paths = <String>[];
    for (var i = 0; i < timesMs.length; i++) {
      final File out = File('${outDir.path}/frame_${_written++}.jpg')..writeAsBytesSync(<int>[0xff, 0xd8]);
      paths.add(out.path);
    }
    return paths;
  }
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('live_prep_test');
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('a valid clip is ready, with a poster and 3 frames at start, middle and end', () async {
    final _FakeMedia media = _FakeMedia(dir);

    final LivePrepResult result = await prepareLiveVideo(File('test/fixtures/live/p.mp4'), media: media);

    expect(result, isA<LivePrepReady>());
    final LivePrepReady ready = result as LivePrepReady;
    expect(ready.poster.path, startsWith(dir.path));
    expect(ready.input.framePaths, hasLength(3));
    expect(ready.input.info.durationMs, 1000);
    expect(media.timesCalls, <List<int>>[
      <int>[0],
      <int>[0, 500, 900],
    ]);
    expect(media.sizeCalls, <(int, int)>[(3200, 92), (1024, 80)]);
  });

  test('a clip over 15 s is refused without asking the native side for frames', () async {
    final _FakeMedia media = _FakeMedia(dir);

    final LivePrepResult result = await prepareLiveVideo(File('test/fixtures/live/long.mp4'), media: media);

    expect(result, isA<LivePrepRefused>());
    expect((result as LivePrepRefused).error, LiveVideoError.tooLong);
    expect(media.timesCalls, isEmpty);
  });

  test('a file over the size limit is refused by its length, before its bytes are read', () async {
    final File huge = File('${dir.path}/huge.mp4');
    final RandomAccessFile raf = await huge.open(mode: FileMode.write);
    await raf.truncate(LiveUploadLimits.maxBytes + 1);
    await raf.close();
    final _FakeMedia media = _FakeMedia(dir);

    final LivePrepResult result = await prepareLiveVideo(huge, media: media);

    expect((result as LivePrepRefused).error, LiveVideoError.tooLarge);
    expect(media.timesCalls, isEmpty);
  });

  test('a native frame failure is refused as malformed', () async {
    final LivePrepResult result = await prepareLiveVideo(
      File('test/fixtures/live/p.mp4'),
      media: _FakeMedia(dir, fail: true),
    );

    expect((result as LivePrepRefused).error, LiveVideoError.malformed);
  });

  test('liveVideoErrorMessage gives the copy for each refusal', () {
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
    expect(liveVideoErrorMessage(l10n, LiveVideoError.codec), l10n.liveUploadErrorCodec);
    expect(liveVideoErrorMessage(l10n, LiveVideoError.noVideoTrack), l10n.liveUploadErrorUnreadable);
    expect(liveVideoErrorMessage(l10n, LiveVideoError.tooBigFrame), l10n.liveUploadErrorFrameSize);
  });
}
