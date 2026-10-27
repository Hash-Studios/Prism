/// How well a wall works as an iOS 26 Spatial Scene, read from `walls.spatial.tier`.
enum WallSpatialTier {
  /// The near and far parts split clearly. A strong 3D effect.
  great,

  /// Some split. A gentle 3D effect.
  ok,

  /// Too flat for a Spatial Scene.
  none;

  bool get suitsSpatialScene => this != none;

  /// Null for a missing or unknown value, which means the wall was not checked.
  static WallSpatialTier? parse(Object? value) {
    for (final tier in values) {
      if (tier.name == value) return tier;
    }
    return null;
  }
}

/// `walls.spatial`: the tier and the URL of the wall's depth map (grey PNG, bright is near).
final class WallSpatial {
  const WallSpatial({required this.tier, this.mapUrl});

  final WallSpatialTier tier;

  /// Null when the stored value is not an https URL.
  final String? mapUrl;

  /// Null when [value] is not a map with a known tier.
  static WallSpatial? parse(Object? value) {
    if (value is! Map) return null;
    final WallSpatialTier? tier = WallSpatialTier.parse(value['tier']);
    if (tier == null) return null;
    final Object? map = value['map'];
    final Uri? uri = map is String ? Uri.tryParse(map) : null;
    final bool https = uri != null && uri.isScheme('https') && uri.host.isNotEmpty;
    return WallSpatial(tier: tier, mapUrl: https ? map as String? : null);
  }

  Map<String, Object?> toJson() => <String, Object?>{'tier': tier.name, 'map': ?mapUrl};

  @override
  bool operator ==(Object other) => other is WallSpatial && other.tier == tier && other.mapUrl == mapUrl;

  @override
  int get hashCode => Object.hash(tier, mapUrl);
}
