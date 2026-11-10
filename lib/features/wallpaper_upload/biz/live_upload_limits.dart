import 'dart:convert';
import 'dart:typed_data';

/// Limits of a creator live wall video. functions/src/liveVideo.ts has the same values and the same header reader,
/// and the server checks the file again.
abstract final class LiveUploadLimits {
  static const int maxBytes = 20 * 1024 * 1024;
  static const int maxDurationMs = 15000;
  static const int maxWidth = 1440;
  static const int maxHeight = 3200;
}

/// Why a picked video can't be a live wall. The names match the server error codes.
enum LiveVideoError { notMp4, malformed, noVideoTrack, codec, tooLarge, tooLong, landscape, tooBigFrame }

/// The facts of an MP4 read from its box headers.
final class LiveVideoInfo {
  const LiveVideoInfo({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.codec,
    required this.bytes,
  });

  final int durationMs;

  /// Display size, after the track rotation.
  final int width;
  final int height;
  final String codec;
  final int bytes;
}

sealed class LiveVideoCheck {
  const LiveVideoCheck();
}

final class LiveVideoOk extends LiveVideoCheck {
  const LiveVideoOk(this.info);
  final LiveVideoInfo info;
}

final class LiveVideoRefused extends LiveVideoCheck {
  const LiveVideoRefused(this.error);
  final LiveVideoError error;
}

const Set<String> _mp4Brands = <String>{
  'isom', 'iso2', 'iso3', 'iso4', 'iso5', 'iso6', 'mp41', 'mp42', 'avc1', 'M4V ', 'M4VP', //
  'dash', 'msnv', '3gp4', '3gp5', '3gp6',
};
const Set<String> _h264 = <String>{'avc1', 'avc3'};

typedef _Box = ({String type, int start, int end});

class _Malformed implements Exception {}

/// Reads [bytes] as an MP4 and checks it against [LiveUploadLimits]. Pure: it never reads a file name.
LiveVideoCheck inspectLiveVideo(Uint8List bytes) {
  if (bytes.length > LiveUploadLimits.maxBytes) return const LiveVideoRefused(LiveVideoError.tooLarge);
  final ByteData data = ByteData.sublistView(bytes);
  String text(int from, int to) => latin1.decode(bytes.sublist(from, to));
  if (bytes.length < 16 || text(4, 8) != 'ftyp') return const LiveVideoRefused(LiveVideoError.notMp4);

  List<_Box> boxes(int from, int to) {
    final List<_Box> found = <_Box>[];
    int at = from;
    while (at < to) {
      if (to - at < 8) throw _Malformed();
      int size = data.getUint32(at);
      final String type = text(at + 4, at + 8);
      int header = 8;
      if (size == 1) {
        if (to - at < 16) throw _Malformed();
        size = data.getUint64(at + 8);
        header = 16;
      } else if (size == 0) {
        size = to - at;
      }
      if (size < header || at + size > to) throw _Malformed();
      found.add((type: type, start: at + header, end: at + size));
      at += size;
    }
    return found;
  }

  _Box need(_Box? box, int length) {
    if (box == null || box.end - box.start < length) throw _Malformed();
    return box;
  }

  _Box? child(_Box box, String type) {
    for (final _Box b in boxes(box.start, box.end)) {
      if (b.type == type) return b;
    }
    return null;
  }

  int uint(int at, {required bool wide}) => wide ? data.getUint64(at) : data.getUint32(at);

  try {
    final List<_Box> top = boxes(0, bytes.length);
    final _Box ftyp = need(top.first, 8);
    final List<String> brands = <String>[text(ftyp.start, ftyp.start + 4)];
    for (int at = ftyp.start + 8; at + 4 <= ftyp.end; at += 4) {
      brands.add(text(at, at + 4));
    }
    if (brands.first == 'qt  ' || !brands.any(_mp4Brands.contains))
      return const LiveVideoRefused(LiveVideoError.notMp4);
    final _Box? moov = top.where((b) => b.type == 'moov').firstOrNull;
    if (moov == null || !top.any((b) => b.type == 'mdat')) return const LiveVideoRefused(LiveVideoError.malformed);

    final _Box mvhd = need(child(moov, 'mvhd'), 20);
    final bool mvhdWide = bytes[mvhd.start] == 1;
    final int timescaleAt = mvhd.start + 4 + (mvhdWide ? 16 : 8);
    need(mvhd, timescaleAt - mvhd.start + (mvhdWide ? 12 : 8));
    final int timescale = data.getUint32(timescaleAt);
    if (timescale == 0) return const LiveVideoRefused(LiveVideoError.malformed);
    final int durationMs = (uint(timescaleAt + 4, wide: mvhdWide) * 1000 / timescale).round();

    final List<({_Box trak, _Box mdia})> video = <({_Box trak, _Box mdia})>[];
    for (final _Box trak in boxes(moov.start, moov.end).where((b) => b.type == 'trak')) {
      final _Box mdia = need(child(trak, 'mdia'), 8);
      final _Box hdlr = need(child(mdia, 'hdlr'), 12);
      if (text(hdlr.start + 8, hdlr.start + 12) == 'vide') video.add((trak: trak, mdia: mdia));
    }
    if (video.length != 1) return const LiveVideoRefused(LiveVideoError.noVideoTrack);
    final (:trak, :mdia) = video.single;

    final _Box stbl = need(child(need(child(mdia, 'minf'), 8), 'stbl'), 8);
    final _Box stsd = need(child(stbl, 'stsd'), 16);
    final String codec = text(stsd.start + 12, stsd.start + 16);
    if (!_h264.contains(codec)) return const LiveVideoRefused(LiveVideoError.codec);

    final _Box tkhd = need(child(trak, 'tkhd'), 84);
    final bool tkhdWide = bytes[tkhd.start] == 1;
    final int matrixAt = tkhd.start + 4 + (tkhdWide ? 32 : 20) + 16;
    need(tkhd, matrixAt - tkhd.start + 44);
    final bool rotated = data.getInt32(matrixAt) == 0 && data.getInt32(matrixAt + 16) == 0;
    final int storedWidth = (data.getUint32(matrixAt + 36) / 65536).round();
    final int storedHeight = (data.getUint32(matrixAt + 40) / 65536).round();
    final int width = rotated ? storedHeight : storedWidth;
    final int height = rotated ? storedWidth : storedHeight;
    if (width <= 0 || height <= 0 || durationMs <= 0) return const LiveVideoRefused(LiveVideoError.malformed);

    if (durationMs > LiveUploadLimits.maxDurationMs) return const LiveVideoRefused(LiveVideoError.tooLong);
    if (height <= width) return const LiveVideoRefused(LiveVideoError.landscape);
    if (width > LiveUploadLimits.maxWidth || height > LiveUploadLimits.maxHeight) {
      return const LiveVideoRefused(LiveVideoError.tooBigFrame);
    }
    return LiveVideoOk(
      LiveVideoInfo(durationMs: durationMs, width: width, height: height, codec: codec, bytes: bytes.length),
    );
    // A box can point past the end of a short read, so ByteData throws RangeError for a truncated file.
    // ignore: avoid_catching_errors
  } on RangeError {
    return const LiveVideoRefused(LiveVideoError.malformed);
  } on _Malformed {
    return const LiveVideoRefused(LiveVideoError.malformed);
  }
}

/// The server error code of [error], as functions/src/liveVideo.ts writes it.
String liveVideoErrorCode(LiveVideoError error) => switch (error) {
  LiveVideoError.notMp4 => 'not_mp4',
  LiveVideoError.malformed => 'malformed',
  LiveVideoError.noVideoTrack => 'no_video_track',
  LiveVideoError.codec => 'codec',
  LiveVideoError.tooLarge => 'too_large',
  LiveVideoError.tooLong => 'too_long',
  LiveVideoError.landscape => 'landscape',
  LiveVideoError.tooBigFrame => 'too_big_frame',
};

/// The [LiveVideoError] of a server code. Null for an unknown code.
LiveVideoError? liveVideoErrorFromCode(Object? code) {
  for (final LiveVideoError error in LiveVideoError.values) {
    if (liveVideoErrorCode(error) == code) return error;
  }
  return null;
}

/// Where the moderation frames come from: start, middle and end of the clip.
List<int> liveFrameTimesMs(int durationMs) => <int>[0, durationMs ~/ 2, (durationMs - 100).clamp(0, durationMs)];
