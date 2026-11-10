import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/features/wallpaper_upload/biz/live_upload_limits.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture(String name) => File('test/fixtures/live/$name').readAsBytesSync();

LiveVideoError _refusal(Uint8List bytes) => (inspectLiveVideo(bytes) as LiveVideoRefused).error;

void main() {
  test('a 1 s portrait H.264 MP4 is ok', () {
    final LiveVideoCheck check = inspectLiveVideo(_fixture('p.mp4'));

    expect(check, isA<LiveVideoOk>());
    final LiveVideoInfo info = (check as LiveVideoOk).info;
    expect(info.durationMs, 1000);
    expect(info.width, 64);
    expect(info.height, 128);
    expect(info.codec, 'avc1');
  });

  test('a stored landscape frame with a 90 degree rotation reads as portrait', () {
    final LiveVideoInfo info = (inspectLiveVideo(_fixture('rot.mp4')) as LiveVideoOk).info;

    expect(info.width, 64);
    expect(info.height, 128);
  });

  test('HEVC is refused as a codec error', () {
    expect(_refusal(_fixture('h.mp4')), LiveVideoError.codec);
  });

  test('a 16 s clip is refused as too long', () {
    expect(_refusal(_fixture('long.mp4')), LiveVideoError.tooLong);
  });

  test('a landscape clip is refused', () {
    expect(_refusal(_fixture('land.mp4')), LiveVideoError.landscape);
  });

  test('a QuickTime .mov is refused as not an MP4', () {
    expect(_refusal(_fixture('q.mov')), LiveVideoError.notMp4);
  });

  test('a JPEG renamed to .mp4 is refused as not an MP4', () {
    final Uint8List jpeg = Uint8List.fromList(<int>[0xff, 0xd8, 0xff, ...List<int>.filled(60, 0)]);

    expect(_refusal(jpeg), LiveVideoError.notMp4);
  });

  test('a clip cut 30 bytes short is malformed', () {
    final Uint8List full = _fixture('p.mp4');

    expect(_refusal(Uint8List.sublistView(full, 0, full.length - 30)), LiveVideoError.malformed);
  });

  test('a file over the size limit is refused without reading its boxes', () {
    expect(_refusal(Uint8List(LiveUploadLimits.maxBytes + 1)), LiveVideoError.tooLarge);
  });

  test('every error has a server code that reads back to the same error', () {
    for (final LiveVideoError error in LiveVideoError.values) {
      expect(liveVideoErrorFromCode(liveVideoErrorCode(error)), error);
    }
    expect(liveVideoErrorFromCode('too_long'), LiveVideoError.tooLong);
    expect(liveVideoErrorFromCode('nope'), isNull);
  });

  test('frames are taken at the start, the middle and just before the end', () {
    expect(liveFrameTimesMs(10000), <int>[0, 5000, 9900]);
  });
}
