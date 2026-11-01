/// `walls.desktopVariant`: the desktop companion of a Studio wall. Only the server writes it.
final class WallDesktopVariant {
  const WallDesktopVariant({
    required this.version,
    required this.thumbnailUrl,
    required this.width,
    required this.height,
  });

  /// Names one companion, so a new one never reuses an old cache.
  final String version;

  /// Public 960 x 600 preview. The full 2560 x 1600 file needs original access.
  final String thumbnailUrl;
  final int width;
  final int height;

  /// Null unless [value] is a map with a 16 hex digit version, an https thumbnail and a landscape size.
  static WallDesktopVariant? parse(Object? value) {
    if (value is! Map) return null;
    final Object? version = value['v'];
    final Object? thumb = value['thumb'];
    final Object? width = value['width'];
    final Object? height = value['height'];
    final Uri? uri = thumb is String ? Uri.tryParse(thumb) : null;
    if (version is! String ||
        !RegExp(r'^[a-f0-9]{16}$').hasMatch(version) ||
        uri == null ||
        !uri.isScheme('https') ||
        uri.host.isEmpty ||
        width is! int ||
        height is! int ||
        width <= height) {
      return null;
    }
    return WallDesktopVariant(version: version, thumbnailUrl: thumb! as String, width: width, height: height);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'v': version,
    'thumb': thumbnailUrl,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is WallDesktopVariant &&
      other.version == version &&
      other.thumbnailUrl == thumbnailUrl &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(version, thumbnailUrl, width, height);
}
