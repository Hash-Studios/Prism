/// What a wall is: a still image, or a creator's looping video. Read from `walls.kind`.
enum WallKind {
  still,
  live;

  /// A missing or unknown value is a still wall. Walls saved before live walls have no `kind`.
  static WallKind parse(Object? value) => value == 'live' ? live : still;
}

/// `walls.live`: the video of a live wall. `wallpaper_url` and `wallpaper_thumb` hold its poster frame.
final class WallLive {
  const WallLive({
    required this.videoUrl,
    this.durationMs,
    this.width,
    this.height,
    this.loop = true,
    this.verified = false,
  });

  /// Public https URL of the H.264 MP4.
  final String videoUrl;

  /// Read by the server from the MP4 headers. Null until the server checked the file.
  final int? durationMs;
  final int? width;
  final int? height;
  final bool loop;

  /// True after the server proved the upload and read its headers. Only verified walls can be approved.
  final bool verified;

  /// Null unless [kind] is `live` and [value] has an https video URL. A broken live wall then shows as its poster.
  static WallLive? parse({required Object? kind, required Object? value}) {
    if (WallKind.parse(kind) != WallKind.live || value is! Map) return null;
    final Object? video = value['video'];
    final Uri? uri = video is String ? Uri.tryParse(video) : null;
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) return null;
    int? positive(Object? raw) => raw is num && raw.isFinite && raw > 0 ? raw.toInt() : null;
    return WallLive(
      videoUrl: video! as String,
      durationMs: positive(value['durationMs']),
      width: positive(value['width']),
      height: positive(value['height']),
      loop: value['loop'] != false,
      verified: value['verified'] == true,
    );
  }

  /// The cache shape. [parse] reads it back with `kind: 'live'`.
  Map<String, Object?> toJson() => <String, Object?>{
    'video': videoUrl,
    'durationMs': ?durationMs,
    'width': ?width,
    'height': ?height,
    'loop': loop,
    'verified': verified,
  };

  @override
  bool operator ==(Object other) =>
      other is WallLive &&
      other.videoUrl == videoUrl &&
      other.durationMs == durationMs &&
      other.width == width &&
      other.height == height &&
      other.loop == loop &&
      other.verified == verified;

  @override
  int get hashCode => Object.hash(videoUrl, durationMs, width, height, loop, verified);
}
